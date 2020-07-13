{ Copyright (C) 2020 by Bill Stewart (bstewart at iname.com)

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
{$H+}

unit
  wsWinEnvVar;

interface

uses
  windows,
  wsWinProcess, wsWinstring;

const
  ERROR_EXE_MACHINE_TYPE_MISMATCH = 216;
  MAX_ENVVAR_NAME_LENGTH          = 127;
  MAX_ENVVAR_VALUE_LENGTH         = 16383;
  THREADPROC_ROUTINE_LENGTH       = 64;

// Returns whether the environment variable exists in current process.
function EnvVarExists(const Name: string): boolean;

// Gets the value of an environment variable as a string.
function GetEnvVar(const Name: string): string;

// Sets (or removes) the value of an environment variable in a specified
// process (to remove a variable: Set Value parameter to empty string).
// Current and other process must match "bitness" (i.e., the processes must
// both be 32-bit or they must both be 64-bit). Returns zero for success, or
// non-zero for failure.
function SetEnvVarInProcess(const ProcessID: DWORD; const Name, Value: string): DWORD;

implementation

type
  TSetEnvironmentVariable = function(lpName:  LPCWSTR;
                                     lpValue: LPCWSTR): BOOL; stdcall;
  TCreateRemoteThread = function(hProcess:           HANDLE;
                                 lpThreadAttributes: LPSECURITY_ATTRIBUTES;
                                 dwStackSize:        SIZE_T;
                                 lpStartAddress:     LPTHREAD_START_ROUTINE;
                                 lpParameter:        LPVOID;
                                 dwCreationFlags:    DWORD;
                                 lpThreadId:         LPDWORD): HANDLE; stdcall;
  TEnvVarNameBuffer = array[0..MAX_ENVVAR_NAME_LENGTH] of widechar;
  TEnvVarValueBuffer = array[0..MAX_ENVVAR_VALUE_LENGTH] of widechar;
  TSetEnvVarCodeBuffer = packed record
    SetEnvironmentVariable: TSetEnvironmentVariable;
    Name:                   TEnvVarNameBuffer;
    Value:                  TEnvVarValueBuffer;
    Routine:                array[0..THREADPROC_ROUTINE_LENGTH - 1] of byte;
    end;
  PSetEnvVarCodeBuffer = ^TSetEnvVarCodeBuffer;

{ TSetEnvVarCodeBuffer members:

  * SetEnvironmentVariable: Address of SetEnvironmentVariableW function
  * Name: Unicode string containing variable name
  * Value: Unicode string containing variable value
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

function EnvVarExists(const Name: string): boolean;
  begin
  GetEnvironmentVariable(pchar(Name),  // LPCSTR Name
                         nil,          // LPSTR  lpBuffer
                         0);           // DWORD  nSize
  result := GetLastError() <> ERROR_ENVVAR_NOT_FOUND;
  end;

function GetEnvVar(const Name: string): string;
  var
    pWideName, pBuffer: pwidechar;
    NumChars, BufSize: DWORD;
  begin
  result := '';
  pWideName := pwidechar(StringToUnicodeString(pchar(Name)));
  // First call: Get number of characters needed for buffer
  NumChars := GetEnvironmentVariableW(pWideName,  // LPCWSTR lpName
                                      nil,        // LPWSTR  lpBuffer
                                      0);         // DWORD   nSize
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pBuffer, BufSize);
    if GetEnvironmentVariableW(pWideName,          // LPCWSTR lpName
                               pBuffer,            // LPWSTR  lpBuffer
                               NumChars) > 0 then  // DWORD   nSize
      result := UnicodeStringToString(pBuffer);
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
    pRoutine: pointer;
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
  CreateRemoteThread := TCreateRemoteThread(GetProcAddress(GetModuleHandle('kernel32'), 'CreateRemoteThread'));
  if CreateRemoteThread = nil then exit(GetLastError());

  // Initialize code buffer
  FillChar(CodeBuffer, SizeOf(CodeBuffer), 0);

  // Get address of SetEnvironmentVariableW
  CodeBuffer.SetEnvironmentVariable := TSetEnvironmentVariable(GetProcAddress(GetModuleHandle('kernel32'), 'SetEnvironmentVariableW'));
  if CodeBuffer.SetEnvironmentVariable = nil then exit(GetLastError());

  // Copy variable name to code buffer
  NameBuffer := StringToUnicodeString(Name);
  Move(NameBuffer, CodeBuffer.Name, SizeOf(NameBuffer));

  // Set or clear the environment variable?
  if Length(Value) > 0 then
    begin
    // Copy variable value to code buffer
    ValueBuffer := StringToUnicodeString(Value);
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
                          true,           // BOOL  bInheritHandle
                          ProcessID);     // DWORD dwProcessId
  if hProcess <> 0 then
    begin
    // Allocate memory in processs
    pCodeBuffer := VirtualAllocEx(hProcess,                 // HANDLE hProcess
                                  nil,                      // LPVOID lpAddress
                                  SizeOf(CodeBuffer),       // DWORD  dwSize
                                  MEM_COMMIT,               // DWORD  flAllocationType
                                  PAGE_EXECUTE_READWRITE);  // DWORD  flProtect
    if pCodeBuffer <> nil then
      begin
      // Copy code buffer to process
      OK := WriteProcessMemory(hProcess,            // HANDLE  hProcess
                               pCodeBuffer,         // LPVOID  lpBaseAddress
                               @CodeBuffer,         // LPCVOID lpBuffer
                               SizeOf(CodeBuffer),  // SIZE_T  nSize
                               BytesWritten);       // SIZE_T  lpNumberOfBytesWritten
      if OK then
        begin
        // Execute function in process
        hThread := CreateRemoteThread(hProcess,                  // HANDLE                 hProcess
                                      nil,                       // LPSECURITY_ATTRIBUTES  lpThreadAttributes
                                      0,                         // SIZE_T                 dwStackSize
                                      @pCodeBuffer^.Routine[0],  // LPTHREAD_START_ROUTINE lpStartAddress
                                      pCodeBuffer,               // LPVOID                 lpParameter
                                      0,                         // DWORD                  dwCreationFlags
                                      nil);                      // LPDWORD                lpThreadId
        if hThread <> 0 then
          begin
          // Wait for thread to complete
          if WaitForSingleObject(hThread, INFINITE) <> WAIT_FAILED then
            begin
            // Get exit code of thread
            if GetExitCodeThread(hThread, ThreadExitCode) then
              begin
              if ThreadExitCode <> 0 then
                result := 0
              else  // Thread exit code <> 0
                result := GetLastError();
              end
            else  // GetExitCodeThread() failed
              result := GetLastError();
            end
          else  // WaitForSingleObject() failed
            result := GetLastError();
          CloseHandle(hThread);
          end
        else  // CreateRemoteThread() failed
          result := GetLastError();
        end
      else  // WriteProcessMemory() failed
        result := GetLastError();
      // Free memory in process
      if not VirtualFreeEx(hProcess,          // HANDLE hProcess
                           pCodeBuffer,       // LPVOID lpAddress
                           0,                 // SIZE_T dwSize
                           MEM_RELEASE) then  // DWORD  dwFreeType
        result := GetLastError();
      end
    else  // VirtualAllocEx() failed
      result := GetLastError();
    CloseHandle(hProcess);
    end
  else  // OpenProcess() failed
    result := GetLastError();
  end;

// Sample routine to return '='-delimited list of environment variable names
function GetEnvVarNames(): string;
  var
    pEntries, pEntry: pchar;
    Entry, Name: string;
  begin
  result := '';
  pEntries := GetEnvironmentStrings();
  if pEntries <> nil then
    begin
    pEntry := pEntries;
    while pEntry^ <> #0 do
      begin
      if pEntry[0] <> '=' then
        begin
        Entry := string(pEntry);
        Name := Copy(Entry, 1, Pos('=', Entry) - 1);
        if result = '' then
          result := Name
        else
          result := result + '=' + Name;
        end;
      Inc(pEntry, Length(pEntry) + SizeOf(char));
      end;
    FreeEnvironmentStrings(pEntries);
    end;
  end;

begin
end.
