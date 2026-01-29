{ Copyright (C) 2020-2026 by Bill Stewart (bstewart at iname.com)

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

unit WinConsole;

interface

// Outputs string to console
procedure OutStr(const S: string);

function GetConsoleCols(): Integer;

function GetConsoleRows(): Integer;

function WhereX(): Integer;

function WhereY(): Integer;

procedure GotoXY(const PosX, PosY: Integer);

// Moves cursor left, taking into account line wrap
procedure MoveCursorLeft(const NumChars: Integer);

// Moves cursor right, taking into account line wrap
procedure MoveCursorRight(const NumChars: Integer);

// Enable: Enables the ENABLE_VIRTUAL_TERMINAL_PROCESSING bit for ConOut
// Disable: Disables the bit
procedure SetConsoleVTMode(const Enable: Boolean);

implementation

uses
  windows,
  WinProcess;

var
  ConOut: HANDLE;
  WindowsTerminal: Boolean;

procedure OutStr(const S: string);
begin
  WriteConsoleW(ConOut,  // HANDLE  hConsoleOutput
    PChar(S),            // VOID    *lpBuffer
    Length(S),           // DWORD   nNumberOfCharsToWrite
    nil,                 // LPDWORD lpNumberOfCharsWritten
    nil);                // LPVOID  lpReserved
end;

function GetConsoleCols(): Integer;
var
  CSBInfo: CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(ConOut,  // HANDLE                      hConsoleOutput
    CSBInfo);                         // PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo
  if WindowsTerminal then
    result := CSBInfo.srWindow.Right - CSBInfo.srWindow.Left + 1
  else
    result := CSBInfo.dwSize.X;
end;

function GetConsoleRows(): Integer;
var
  CSBInfo: CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(ConOut,  // HANDLE                      hConsoleOutput
    CSBInfo);                         // PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo
  if WindowsTerminal then
    result := CSBInfo.srWindow.Bottom - CSBInfo.srWindow.Top + 1
  else
    result := CSBInfo.dwSize.Y;
end;

function WhereX(): Integer;
var
  CSBInfo: CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(ConOut,  // HANDLE                      hConsoleOutput
    CSBInfo);                         // PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo
  result := CSBInfo.dwCursorPosition.X + 1;
end;

function WhereY(): Integer;
var
  CSBInfo: CONSOLE_SCREEN_BUFFER_INFO;
begin
  GetConsoleScreenBufferInfo(ConOut,  // HANDLE                      hConsoleOutput
    CSBInfo);                         // PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo
  result := CSBInfo.dwCursorPosition.Y + 1;
end;

procedure GotoXY(const PosX, PosY: Integer);
var
  CoordCursor: COORD;
begin
  if (PosX >= 1) and (PosX <= GetConsoleCols()) and (PosY >= 1) and (PosY <= GetConsoleRows()) then
  begin
    CoordCursor.X := PosX - 1;
    CoordCursor.Y := PosY - 1;
    SetConsoleCursorPosition(ConOut,  // HANDLE hConsoleOutput
      CoordCursor);                   // COORD  dwCursorPosition
  end;
end;

procedure MoveCursorLeft(const NumChars: Integer);
var
  X, Y, I: Integer;
begin
  X := WhereX();
  Y := WhereY();
  for I := 1 to NumChars do
  begin
    if X = 1 then               // at column 1
    begin
      if Y > 1 then             // if we're past row 1
      begin
        X := GetConsoleCols();  // move to last column
        Dec(Y);                 // on previous row
      end;
    end
    else                        // not at column 1
      Dec(X);                   // move left one column
  end;
  GotoXY(X, Y);
end;

procedure MoveCursorRight(const NumChars: Integer);
var
  X, Y, I: Integer;
begin
  X := WhereX();
  Y := WhereY();
  for I := 1 to NumChars do
  begin
    if X = GetConsoleCols() then
    begin
      if Y < GetConsoleRows() then
      begin
        X := 1;  // move to first column
        Inc(Y);  // on next row
      end;
    end
    else         // we're not at the right-most column
      Inc(X);    // move right one column
  end;
  GotoXY(X, Y);
end;

procedure SetConsoleVTMode(const Enable: Boolean);
var
  OldMode, NewMode: DWORD;
begin
  GetConsoleMode(ConOut,  // HANDLE  hConsoleHandle
    NewMode);             // LPDWORD lpMode
  OldMode := NewMode;
  if Enable then
  begin
    NewMode := NewMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
  end
  else
  begin
    NewMode := NewMode and (not ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  end;
  if OldMode <> NewMode then
    SetConsoleMode(ConOut,  // HANDLE hConsoleHandle  
      NewMode);             // DWORD  dwMode
end;

procedure InitializeUnit();
var
  ProcessID: DWORD;
begin
  ProcessID := GetCurrentProcessId();
  if not IsParentProcessName(ProcessID, 'powershell_ise.exe') then
  begin
    ConOut := CreateFile('CONOUT$',   // LPCTSTR               lpFileName
      GENERIC_READ or GENERIC_WRITE,  // DWORD                 dwDesiredAccess
      FILE_SHARE_READ,                // DWORD                 dwShareMode
      nil,                            // LPSECURITY_ATTRIBUTES lpSecurityAttributes
      OPEN_EXISTING,                  // DWORD                 dwCreationDisposition
      0,                              // DWORD                 dwFlagsAndAttributes
      0);                             // HANDLE                hTemplateFile
  end
  else
    ConOut := StdOutputHandle;
  // See this for info on why we need to know if WT is running:
  // https://github.com/microsoft/terminal/issues/10191#issuecomment-897345862
  // Basically in WT you can't move "backward" into the scrollback bufffer
  WindowsTerminal := IsProcessInTree(ProcessID, 'windowsterminal.exe');
end;

procedure FinalizeUnit();
begin
  ConOut := StdOutputHandle;
end;

initialization
  InitializeUnit();

finalization
  FinalizeUnit();

end.
