{ Copyright (C) 2020-2026 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

unit WinProcess;

interface

uses
  windows;

// Returns the process ID of the parent process of the specified process
function GetParentProcessID(const ProcessID: DWORD; out ParentProcessID: DWORD): DWORD;

// Returns true if the specified executable's name is the parent process of
// the specified process, or false otherwise
function IsParentProcessName(const ProcessID: DWORD; const ProcessName: string): Boolean;

// Returns true if the specified executable name is running in the specified
// process ID's process tree, or false otherwise
function IsProcessInTree(const ProcessID: DWORD; const ProcessName: string): Boolean;

// Returns true if the current process and parent process are both 32-bit
// or are both 64-bit, or false otherwise
function CurrentProcessMatchesProcessBits(const ProcessID: DWORD): Boolean;

implementation

uses
  WindowsString;  // https://github.com/Bill-Stewart/WindowsString

type
  TProcessEntry = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: ULONG_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: LONG;
    dwFlags: DWORD;
    szExeFile: array[0..MAX_PATH - 1] of WCHAR;
  end;

function CreateToolhelp32Snapshot(DwFlags: DWORD; th32ProcessID: DWORD): HANDLE;
  stdcall; external 'kernel32.dll';

function Process32FirstW(hSnapshot: HANDLE; var lppe: TProcessEntry): BOOL;
  stdcall; external 'kernel32.dll';

function Process32NextW(hSnapshot: HANDLE; var lppe: TProcessEntry): BOOL;
  stdcall; external 'kernel32.dll';

// Gets the TProcessEntry for the specified process ID
function GetProcessEntry(const ProcessID: DWORD; out ProcessEntry: TProcessEntry): DWORD;
const
  TH32CS_SNAPPROCESS = 2;
var
  Snapshot: HANDLE;
  OK: BOOL;
begin
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,  // DWORD dwFlags
    0);                                                     // DWORD th32ProcessID
  if Snapshot = INVALID_HANDLE_VALUE then
  begin
    result := GetLastError();
    exit;
  end;
  result := ERROR_SUCCESS;
  ProcessEntry.dwSize := SizeOf(TProcessEntry);
  OK := Process32FirstW(Snapshot,  // HANDLE            hSnapshot
    ProcessEntry);                 // LPPROCESSENTRY32W lppe
  if OK then
  begin
    while OK do
    begin
      if ProcessEntry.th32ProcessID = ProcessID then
        break;
      OK := Process32NextW(Snapshot,  // HANDLE            hSnapshot
        ProcessEntry);                // LPPROCESSENTRY32W lppe
      if not OK then
        result := GetLastError();
    end
  end
  else
    result := GetLastError();
  CloseHandle(Snapshot);  // HANDLE hObject
end;

// Gets the TProcessEntry for the parent process of the specified process ID
function GetParentProcessEntry(const ProcessID: DWORD; out ProcessEntry: TProcessEntry): DWORD;
var
  ProcEntry: TProcessEntry;
begin
  result := GetProcessEntry(ProcessID, ProcEntry);
  if result = ERROR_SUCCESS then
  begin
    result := GetProcessEntry(ProcEntry.th32ParentProcessID, ProcEntry);
    if result = ERROR_SUCCESS then
      ProcessEntry := ProcEntry;
  end;
end;

function GetParentProcessID(const ProcessID: DWORD; out ParentProcessID: DWORD): DWORD;
var
  ProcessEntry: TProcessEntry;
begin
  result := GetParentProcessEntry(ProcessID, ProcessEntry);
  if result = ERROR_SUCCESS then
    ParentProcessID := ProcessEntry.th32ProcessID;
end;

function IsParentProcessName(const ProcessID: DWORD; const ProcessName: string): Boolean;
var
  RC: DWORD;
  ProcessEntry: TProcessEntry;
begin
  result := false;
  RC := GetParentProcessEntry(ProcessID, ProcessEntry);
  if RC = ERROR_SUCCESS then
    result := SameString(string(ProcessEntry.szExeFile), ProcessName);
end;

function IsProcessInTree(const ProcessID: DWORD; const ProcessName: string): Boolean;
var
  RC: DWORD;
  ProcessEntry: TProcessEntry;
begin
  result := false;
  RC := GetProcessEntry(ProcessID, ProcessEntry);
  while RC = ERROR_SUCCESS do
  begin
    result := SameString(string(ProcessEntry.szExeFile), ProcessName);
    if result then
      break;
    RC := GetProcessEntry(ProcessEntry.th32ParentProcessID, ProcessEntry);
  end;
end;

function IsProcessor64Bit(): Boolean;
const
  PROCESSOR_ARCHITECTURE_AMD64 = 9;
  PROCESSOR_ARCHITECTURE_ARM64 = 12;
var
  SystemInfo: SYSTEM_INFO;
  Architecture: Word;
begin
  GetNativeSystemInfo(@SystemInfo);  // LPSYSTEM_INFO lpSystemInfo
  Architecture := SystemInfo.wProcessorArchitecture;
  result := (Architecture = PROCESSOR_ARCHITECTURE_AMD64) or
    (Architecture = PROCESSOR_ARCHITECTURE_ARM64);
end;

function IsProcessWoW64(const ProcessID: DWORD): Boolean;
var
  ProcessHandle: HANDLE;
  IsWoW64: BOOL;
begin
  result := false;
  ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION,  // DWORD dwDesiredAccess
    true,                                                  // BOOL  bInheritHandle
    ProcessID);                                            // DWORD dwProcessId
  if ProcessHandle <> 0 then
  begin
    if IsWow64Process(ProcessHandle,  // HANDLE hProcess
      @IsWoW64) then                  // PBOOL  Wow64Process
    begin
      result := IsWoW64;
    end;
    CloseHandle(ProcessHandle);
  end;
end;

function CurrentProcessMatchesProcessBits(const ProcessID: DWORD): Boolean;
var
  CurrProcID: DWORD;
begin
  CurrProcID := GetCurrentProcessId();
  result := ((not IsProcessWoW64(CurrProcID)) and (not IsProcessWoW64(ProcessID))) or
    (IsProcessWoW64(CurrProcID) and IsProcessWoW64(ProcessID));
end;

begin
end.
