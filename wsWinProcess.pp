{ Copyright (C) 2020-2021 by Bill Stewart (bstewart at iname.com)

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

unit wsWinProcess;

interface

uses
  Windows;

// Retrieves the parent process ID of the current process into the ProcessID
// parameter. Returns zero for success, or non-zero for failure.
function GetParentProcessID(var ProcessID: DWORD): DWORD;

// Returns whether the current process and the specified process match
// "bitness" (i.e., both 32-bit or both 64-bit).
function CurrentProcessMatchesProcessBits(const ProcessID: DWORD): Boolean;

implementation

const
  PROCESSOR_ARCHITECTURE_AMD64 = 9;
  TH32CS_SNAPPROCESS           = 2;

type
  TProcessEntry32 = record
    dwSize:              DWORD;
    cntUsage:            DWORD;
    th32ProcessID:       DWORD;
    th32DefaultHeapID:   ULONG_PTR;
    th32ModuleID:        DWORD;
    cntThreads:          DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase:      LONG;
    dwFlags:             DWORD;
    szExeFile:           array[0..MAX_PATH - 1] of TCHAR;
  end;
  TGetNativeSystemInfo = procedure(var lpSystemInfo: SYSTEM_INFO); stdcall;
  TCreateToolhelp32Snapshot = function(dwFlags: DWORD; th32ProcessId: DWORD): HANDLE;
    stdcall;
  TProcess32First = function(hSnapshot: HANDLE; var lppe: TProcessEntry32): BOOL; stdcall;
  TProcess32Next = function(hSnapshot: HANDLE; var lppe: TProcessEntry32): BOOL; stdcall;
  TIsWow64Process = function(hProcess: HANDLE; var Wow64Process: BOOL): BOOL; stdcall;

function GetParentProcessID(var ProcessID: DWORD): DWORD;
var
  CreateToolhelp32Snapshot: TCreateToolhelp32Snapshot;
  Process32First: TProcess32First;
  Process32Next: TProcess32Next;
  ProcessEntry: TProcessEntry32;
  Snapshot: HANDLE;
  OK: BOOL;
begin
  CreateToolhelp32Snapshot := TCreateToolhelp32Snapshot(GetProcAddress(GetModuleHandle('kernel32'),
    'CreateToolhelp32Snapshot'));
  if not Assigned(CreateToolhelp32Snapshot) then
    exit(GetLastError());
  Process32First := TProcess32First(GetProcAddress(GetModuleHandle('kernel32'),
    'Process32First'));
  if not Assigned(Process32First) then
    exit(GetLastError());
  Process32Next := TProcess32Next(GetProcAddress(GetModuleHandle('kernel32'),
    'Process32Next'));
  if not Assigned(Process32Next) then
    exit(GetLastError());
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then
    exit(GetLastError());
  ProcessEntry.dwSize := SizeOf(TProcessEntry32);
  OK := Process32First(Snapshot, ProcessEntry);
  if OK then
  begin
    ProcessID := 0;
    repeat
      if ProcessEntry.th32ProcessID = GetCurrentProcessId() then
      begin
        ProcessID := ProcessEntry.th32ParentProcessID;
        break;
      end;
      OK := Process32Next(Snapshot, ProcessEntry);
    until not OK;
    if ProcessID > 0 then
      result := 0
    else
      result := ERROR_NO_MORE_FILES;
  end
  else
    result := GetLastError();
  CloseHandle(Snapshot);
end;

// Returns if processor is 64-bit
function IsProcessor64Bit(): Boolean;
var
  GetNativeSystemInfo: TGetNativeSystemInfo;
  SystemInfo: SYSTEM_INFO;
begin
  result := false;
  GetNativeSystemInfo := TGetNativeSystemInfo(GetProcAddress(GetModuleHandle('kernel32'),
    'GetNativeSystemInfo'));
  if not Assigned(GetNativeSystemInfo) then
  begin
    GetNativeSystemInfo(SystemInfo);
    result := SystemInfo.wProcessorArchitecture = PROCESSOR_ARCHITECTURE_AMD64;
  end;
end;

function IsProcessWoW64(const ProcessID: DWORD): Boolean;
var
  IsWow64Process: TIsWow64Process;
  ProcessHandle: HANDLE;
  IsWoW64: BOOL;
begin
  result := false;
  IsWow64Process := TIsWow64Process(GetProcAddress(GetModuleHandle('kernel32'),
    'IsWow64Process'));
  if not Assigned(IsWow64Process) then
    exit();
  ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION,  // DWORD dwDesiredAccess
    true,                                                  // BOOL  bInheritHandle
    ProcessID);                                            // DWORD dwProcessId
  if ProcessHandle <> 0 then
  begin
    if IsWow64Process(ProcessHandle, IsWoW64) then
      result := IsWoW64;
    CloseHandle(ProcessHandle);
  end;
end;

function CurrentProcessMatchesProcessBits(const ProcessID: DWORD): Boolean;
begin
  result := ((not IsProcessWoW64(GetCurrentProcessId())) and (not IsProcessWoW64(ProcessID))) or
    (IsProcessWoW64(GetCurrentProcessId()) and IsProcessWoW64(ProcessID));
end;

begin
end.
