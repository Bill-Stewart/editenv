{ Copyright (C) 2020-2025 by Bill Stewart (bstewart at iname.com)

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

unit WinEnvironment;

interface

uses
  windows;

const
  ERROR_EXE_MACHINE_TYPE_MISMATCH = 216;
  MAX_ENVVAR_NAME_LENGTH = 127;
  MAX_ENVVAR_VALUE_LENGTH = 16383;

// Returns whether the environment variable exists in current process
function EnvVarExists(const Name: string): Boolean;

// Gets the value of an environment variable as a string
function GetEnvVar(const Name: string): string;

// Sets (or removes) the value of an environment variable in a specified
// process (to remove a variable: Set Value parameter to empty string);
// current and other process must match "bitness" (i.e., the processes must
// both be 32-bit or they must both be 64-bit); returns zero for success, or
// non-zero for failure
function SetEnvVarInProcess(const ProcessID: DWORD; const Name, Value: string): DWORD;

implementation

uses
  WinProcess;

const
  THREADPROC_ROUTINE_LENGTH = 64;

type
  TSetEnvironmentVariable = function(lpName: LPCWSTR; lpValue: LPCWSTR): BOOL; stdcall;
  TCreateRemoteThread = function(hProcess: HANDLE;
    lpThreadAttributes: LPSECURITY_ATTRIBUTES;
    dwStackSize: SIZE_T;
    lpStartAddress: LPTHREAD_START_ROUTINE;
    lpParameter: LPVOID; dwCreationFlags: DWORD;
    lpThreadId: LPDWORD): HANDLE; stdcall;
  TEnvVarNameBuffer  = array[0..MAX_ENVVAR_NAME_LENGTH] of Char;
  TEnvVarValueBuffer = array[0..MAX_ENVVAR_VALUE_LENGTH] of Char;
  TSetEnvVarCodeBuffer = packed record
    SetEnvironmentVariable: TSetEnvironmentVariable;
    Name: TEnvVarNameBuffer;
    Value: TEnvVarValueBuffer;
    Routine: array[0..THREADPROC_ROUTINE_LENGTH - 1] of Byte;
  end;
  PSetEnvVarCodeBuffer = ^TSetEnvVarCodeBuffer;

{ TSetEnvVarCodeBuffer members:

  * SetEnvironmentVariable: Address of SetEnvironmentVariableW function
  * Name: String containing variable name
  * Value: String containing variable value
  * Routine: Copy of ThreadProc function

  To set an environment variable in another process:
  1. In code buffer:
     a. Set SetEnvironmentVariable member to address of SetEnvironmentVariableW
     b. Copy environment variable name to Name member
     c. Copy environment variable value to Value member
     d. Copy ThreadProc function to Routine member
  2. Open the other process (OpenProcess)
  3. Allocate memory in the other process (VirtualAllocEx)
  4. Copy code buffer to the other process (WriteProcessMemory)
  5. Execute the function in the other process (CreateRemoteThread)

  For this to work, both processes must match "bitness" (both must be 32-bit or
  both must be 64-bit).
}

function EnvVarExists(const Name: string): Boolean;
begin
  GetEnvironmentVariableW(PChar(Name),  // LPCWSTR Name
    nil,                                // LPWSTR  lpBuffer
    0);                                 // DWORD   nSize
  result := GetLastError() <> ERROR_ENVVAR_NOT_FOUND;
end;

function GetEnvVar(const Name: string): string;
var
  NumChars, BufSize: DWORD;
  pBuffer: PChar;
begin
  result := '';
  NumChars := GetEnvironmentVariableW(PChar(Name),  // LPCWSTR lpName
    nil,                                            // LPWSTR  lpBuffer
    0);                                             // DWORD   nSize
  if NumChars > 0 then
  begin
    BufSize := NumChars * SizeOf(Char);
    GetMem(pBuffer, BufSize);
    if GetEnvironmentVariableW(PChar(Name),  // LPCWSTR lpName
      pBuffer,                               // LPWSTR  lpBuffer
      NumChars) > 0 then                     // DWORD   nSize
      result := string(pBuffer);
    FreeMem(pBuffer, BufSize);
  end;
end;

// Must match ThreadProc function signature
function SetEnvVarThreadProc(const pCodeBuffer: PSetEnvVarCodeBuffer): DWORD; stdcall;
begin
  result := DWORD(pCodeBuffer^.SetEnvironmentVariable(pCodeBuffer^.Name, pCodeBuffer^.Value));
end;

// Must match ThreadProc function signature
function RemoveEnvVarThreadProc(const pCodeBuffer: PSetEnvVarCodeBuffer): DWORD; stdcall;
begin
  result := DWORD(pCodeBuffer^.SetEnvironmentVariable(pCodeBuffer^.Name, nil));
end;

// Sets/removes an environment variable in another process
function SetEnvVarInProcess(const ProcessID: DWORD; const Name, Value: string): DWORD;
var
  CreateRemoteThread: TCreateRemoteThread;
  CodeBuffer: TSetEnvVarCodeBuffer;
  NameBuffer: TEnvVarNameBuffer;
  ValueBuffer: TEnvVarValueBuffer;
  pRoutine: Pointer;
  ProcessAccess: DWORD;
  hProcess: HANDLE;
  pCodeBuffer: PSetEnvVarCodeBuffer;
  OK: BOOL;
  BytesWritten: SIZE_T;
  hThread: HANDLE;
  ThreadExitCode: DWORD;
begin
  result := 0;

  // Variable name cannot contain '=' character
  if (Pos('=', Name) > 0) then
    exit(ERROR_INVALID_PARAMETER);

  // Range-check name and value
  if (Length(Name) > MAX_ENVVAR_NAME_LENGTH) or (Length(Value) > MAX_ENVVAR_VALUE_LENGTH) then
    exit(ERROR_INSUFFICIENT_BUFFER);

  // Fail if "bitness" mismatch
  if not CurrentProcessMatchesProcessBits(ProcessID) then
    exit(ERROR_EXE_MACHINE_TYPE_MISMATCH);

  // Get pointer to function
  CreateRemoteThread := TCreateRemoteThread(GetProcAddress(GetModuleHandle('kernel32'),
    'CreateRemoteThread'));
  if not Assigned(CreateRemoteThread) then
    exit(GetLastError());

  // Initialize code buffer
  FillChar(CodeBuffer, SizeOf(CodeBuffer), 0);

  // Get address of SetEnvironmentVariableW
  CodeBuffer.SetEnvironmentVariable := TSetEnvironmentVariable(GetProcAddress(GetModuleHandle('kernel32'),
    'SetEnvironmentVariableW'));
  if not Assigned(CodeBuffer.SetEnvironmentVariable) then
    exit(GetLastError());

  // Copy variable name to code buffer
  NameBuffer := PChar(Name);
  Move(NameBuffer, CodeBuffer.Name, SizeOf(NameBuffer));

  // Set or clear the environment variable?
  if Length(Value) > 0 then
  begin
    // Copy variable value to code buffer
    ValueBuffer := PChar(Value);
    Move(ValueBuffer, CodeBuffer.Value, SizeOf(ValueBuffer));
    pRoutine := @SetEnvVarThreadProc;
  end
  else
    pRoutine := @RemoveEnvVarThreadProc;

  // Copy ThreadProc function to code buffer
  Move(pRoutine^, CodeBuffer.Routine, SizeOf(CodeBuffer.Routine));

  // Set desired access
  ProcessAccess := PROCESS_CREATE_THREAD or
    PROCESS_VM_OPERATION or
    PROCESS_VM_READ or
    PROCESS_VM_WRITE or
    PROCESS_QUERY_INFORMATION or
    SYNCHRONIZE;
  // Open process
  hProcess := OpenProcess(ProcessAccess,  // DWORD dwDesiredAccess
    true,                                 // BOOL  bInheritHandle
    ProcessID);                           // DWORD dwProcessId
  if hProcess = 0 then
    exit(GetLastError());  // OpenProcess failed

  // Allocate memory in processs
  pCodeBuffer := VirtualAllocEx(hProcess,  // HANDLE hProcess
    nil,                                   // LPVOID lpAddress
    SizeOf(CodeBuffer),                    // DWORD  dwSize
    MEM_COMMIT,                            // DWORD  flAllocationType
    PAGE_EXECUTE_READWRITE);               // DWORD  flProtect
  if Assigned(pCodeBuffer) then
  begin
    // Copy code buffer to process
    OK := WriteProcessMemory(hProcess,  // HANDLE  hProcess
      pCodeBuffer,                      // LPVOID  lpBaseAddress
      @CodeBuffer,                      // LPCVOID lpBuffer
      SizeOf(CodeBuffer),               // SIZE_T  nSize
      BytesWritten);                    // SIZE_T  lpNumberOfBytesWritten
    if OK then
    begin
      // Execute function in process
      hThread := CreateRemoteThread(hProcess,  // HANDLE                 hProcess
        nil,                                   // LPSECURITY_ATTRIBUTES  lpThreadAttributes
        0,                                     // SIZE_T                 dwStackSize
        @pCodeBuffer^.Routine[0],              // LPTHREAD_START_ROUTINE lpStartAddress
        pCodeBuffer,                           // LPVOID                 lpParameter
        0,                                     // DWORD                  dwCreationFlags
        nil);                                  // LPDWORD                lpThreadId
      if hThread <> 0 then
      begin
        // Wait for thread to complete
        if WaitForSingleObject(hThread,  // HANDLE hHandle
          INFINITE) <> WAIT_FAILED then  // DWORD  dwMilliseconds
        begin
          // Get exit code of thread
          if GetExitCodeThread(hThread,  // HANDLE  hThread
            ThreadExitCode) then         // LPDWORD lpExitCode
          begin
            // SetEnvironmentVariableW returns non-zero for success
            if ThreadExitCode <> 0 then
              result := 0
            else  // SetEnvironmentVariableW failed
              result := GetLastError();
          end
          else  // GetExitCodeThread failed
            result := GetLastError();
        end
        else  // WaitForSingleObject failed
          result := GetLastError();
        CloseHandle(hThread);
      end
      else  // CreateRemoteThread failed
        result := GetLastError();
    end
    else  // WriteProcessMemory failed
      result := GetLastError();
    // Free memory in process
    if not VirtualFreeEx(hProcess,  // HANDLE hProcess
      pCodeBuffer,                  // LPVOID lpAddress
      0,                            // SIZE_T dwSize
      MEM_RELEASE) then             // DWORD  dwFreeType
      result := GetLastError();
  end
  else  // VirtualAllocEx failed
    result := GetLastError();
  CloseHandle(hProcess);  // HANDLE hObject
end;

begin
end.
