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

unit wsWinConsole;

interface

uses
  Windows;

// Disable Ctrl+C as signal and ignore Ctrl+Break
procedure DisableBreak();

// Enable Ctrl+C as signal and don't ignore Ctrl+Break
procedure EnableBreak();

function WhereX(): LongInt;

function WhereY(): LongInt;

procedure GotoXY(const PosX, PosY: LongInt);

// Moves cursor left, taking into account line wrap
procedure MoveCursorLeft(const NumChars: LongInt);

// Moves cursor right, taking into account line wrap
procedure MoveCursorRight(const NumChars: LongInt);

implementation

type
  THandlerRoutine = function(dwControlType: DWORD): BOOL; stdcall;

var
  CONIN, CONOUT: HANDLE;
  CSBInfo: CONSOLE_SCREEN_BUFFER_INFO;
  ConsoleWidth, ConsoleHeight: LongInt;

// Windows console signal handler routine
function HandlerRoutine(const dwControlType: DWORD): BOOL; stdcall;
begin
  result := false;     // Pass signal to next handler
  case dwControlType of
    CTRL_BREAK_EVENT:
    begin
      result := true;  // Signal handled
    end;
  end; //case
end;

procedure DisableBreak();
var
  Mode: DWORD;
begin
  GetConsoleMode(CONIN, Mode);
  if Mode and ENABLE_PROCESSED_INPUT <> 0 then
  begin
    SetConsoleMode(CONIN, Mode and (not ENABLE_PROCESSED_INPUT));
    SetConsoleCtrlHandler(THandlerRoutine(@HandlerRoutine), true);
  end;
end;

procedure EnableBreak();
var
  Mode: DWORD;
begin
  GetConsoleMode(CONIN, Mode);
  if Mode and ENABLE_PROCESSED_INPUT = 0 then
  begin
    SetConsoleMode(CONIN, Mode or ENABLE_PROCESSED_INPUT);
    SetConsoleCtrlHandler(nil, false);
  end;
end;

function WhereX(): LongInt;
begin
  GetConsoleScreenBufferInfo(CONOUT, CSBInfo);
  result := CSBInfo.dwCursorPosition.X + 1;
end;

function WhereY(): LongInt;
begin
  GetConsoleScreenBufferInfo(CONOUT, CSBInfo);
  result := CSBInfo.dwCursorPosition.Y + 1;
end;

procedure GotoXY(const PosX, PosY: LongInt);
var
  CoordCursor: COORD;
begin
  if (PosX >= 1) and (PosX <= ConsoleWidth) and (PosY >= 1) and (PosY <= ConsoleHeight) then
  begin
    CoordCursor.X := PosX - 1;
    CoordCursor.Y := PosY - 1;
    SetConsoleCursorPosition(CONOUT, CoordCursor);
  end;
end;

procedure MoveCursorLeft(const NumChars: LongInt);
var
  X, Y: LongInt;
  I: LongInt;
begin
  X := WhereX();
  Y := WhereY();
  for I := 1 to NumChars do
  begin
    if X = 1 then           // at column 1
    begin
      if Y > 1 then         // if we're past row 1
      begin
        X := ConsoleWidth;  // move to last column
        Dec(Y);             // on previous row
      end;
    end
    else                    // not at column 1
      Dec(X);               // move left one column
  end;
  GotoXY(X, Y);
end;

procedure MoveCursorRight(const NumChars: LongInt);
var
  X, Y: LongInt;
  I: LongInt;
begin
  X := WhereX();
  Y := WhereY();
  for I := 1 to NumChars do
  begin
    if X = ConsoleWidth then
    begin
      if Y < ConsoleHeight then
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

procedure InitializeUnit();
var
  Access, Mode: DWORD;
begin
  Access := GENERIC_READ or GENERIC_WRITE;
  CONIN := CreateFile('CONIN$',  // LPCTSTR               lpFileName
    Access,                      // DWORD                 dwDesiredAccess
    FILE_SHARE_READ,             // DWORD                 dwShareMode
    nil,                         // LPSECURITY_ATTRIBUTES lpSecurityAttributes
    OPEN_EXISTING,               // DWORD                 dwCreationDisposition
    0,                           // DWORD                 dwFlagsAndAttributes
    0);                          // HANDLE                hTemplateFile
  GetConsoleMode(CONIN, Mode);

  CONOUT := CreateFile('CONOUT$',  // LPCTSTR               lpFileName
    Access,                        // DWORD                 dwDesiredAccess
    FILE_SHARE_READ,               // DWORD                 dwShareMode
    nil,                           // LPSECURITY_ATTRIBUTES lpSecurityAttributes
    OPEN_EXISTING,                 // DWORD                 dwCreationDisposition
    0,                             // DWORD                 dwFlagsAndAttributes
    0);                            // HANDLE                hTemplateFile
  GetConsoleScreenBufferInfo(CONOUT, CSBInfo);
  ConsoleWidth := CSBInfo.dwSize.X;
  ConsoleHeight := CSBInfo.dwSize.Y;
end;

initialization
  InitializeUnit();

finalization

end.
