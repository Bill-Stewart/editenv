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
  wsWinString;

interface

uses
  windows;

// Expands %environment_variable_name% references in the specified string
// using the ExpandEnvironmentStrings() API and returns the result.
function ExpandEnvStrings(S: string): string;

// Converts the specified string to a Unicode string using the
// MultiByteToWideChar() API and returns the result.
function StringToUnicodeString(const S: string): unicodestring;

// Converts the specified Unicode string to a string using the
// WideCharToMultiByte() API and returns the result.
function UnicodeStringToString(const S: unicodestring): string;

// Converts the specified Unicode string to its base64-encoded representation
// using the CryptBinaryToStringW() and returns the result.
function UnicodeToBase64String(const S: unicodestring): string;

// Converts the specified base64-encoded string to a Unicode string using the
// CryptStringToBinaryW() API and returns the result.
function Base64StringToUnicode(const S: string): unicodestring;

implementation

const
  CRYPT_STRING_BASE64 = $00000001;
  CRYPT_STRING_NOCRLF = $40000000;

function CryptBinaryToStringW(pbBinary:       pointer;
                              cbBinary:       DWORD;
                              dwFlags:        DWORD;
                              pszString:      LPWSTR;
                              var pcchString: DWORD): BOOL; stdcall;
  external 'crypt32.dll';

function CryptStringToBinaryW(pszString:      LPCWSTR;
                              cchString:      DWORD;
                              dwFlags:        DWORD;
                              pbBinary:       PByte;
                              var pcbBinary:  DWORD;
                              pdwSkip:        PDWORD;
                              pdwFlags:       PDWORD): BOOL; stdcall;
  external 'crypt32.dll';

function ExpandEnvStrings(S: string): string;
  var
    BufSize: DWORD;
    pStr: pchar;
  begin
  result := '';
  // First call: Get buffer size needed
  BufSize := ExpandEnvironmentStrings(pchar(S), nil, 0);
  if BufSize > 0 then
    begin
    GetMem(pStr, BufSize);
    if ExpandEnvironmentStrings(pchar(S), pStr, BufSize) > 0 then
      result := string(pStr);
    FreeMem(pStr, BufSize);
    end;
  end;

function StringToUnicodeString(const S: string): unicodestring;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pwidechar;
  begin
  result := '';
  NumChars := MultiByteToWideChar(CP_OEMCP,  // UINT   CodePage
                                  0,         // DWORD  dwFlags
                                  pchar(S),  // LPCCH  lpMultiByteStr
                                  -1,        // int    cbMultiByte
                                  nil,       // LPWSTR lpWideCharStr
                                  0);        // int    cchWideChar
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pBuffer, BufSize);
    if MultiByteToWideChar(CP_OEMCP,          // UINT   CodePage
                           0,                 // DWORD  dwFlags
                          pchar(S),           // LPCCH  lpMultiByteStr
                          -1,                 // int    cbMultiByte
                          pBuffer,            // LPWSTR lpWideCharStr
                          NumChars) > 0 then  // int    cchWideChar
      result := unicodestring(pBuffer);
    FreeMem(pBuffer, BufSize);
    end;
  end;

function UnicodeStringToString(const S: unicodestring): string;
  var
    NumChars, BufSize: DWORD;
    pBuffer: pchar;
  begin
  result := '';
  NumChars := WideCharToMultiByte(CP_OEMCP,      // UINT   CodePage
                                  0,             // DWORD  dwFlags
                                  pwidechar(S),  // LPCWCH lpWideCharStr
                                  -1,            // int    cchWideChar
                                  nil,           // LPSTR  lpMultiByteStr
                                  0,             // int    cbMultiByte
                                  nil,           // LPCCH  lpDefaultChar
                                  nil);          // LPBOOL lpUsedDefaultChar
  if NumChars > 0 then
    begin
    BufSize := NumChars * SizeOf(char);
    GetMem(pBuffer, BufSize);
    if WideCharToMultiByte(CP_OEMCP,      // UINT   CodePage
                           0,             // DWORD  dwFlags
                           pwidechar(S),  // LPCWCH lpWideCharStr
                           -1,            // int    cchWideChar
                           pBuffer,       // LPSTR  lpMultiByteStr
                           NumChars,      // int    cbMultiByte
                           nil,           // LPCCH  lpDefaultChar
                           nil) > 0 then  // LPBOOL lpUsedDefaultChar
      result := string(pBuffer);
    FreeMem(pBuffer, BufSize);
    end;
  end;

function UnicodeToBase64String(const S: unicodestring): string;
  var
    Flags, NumChars, BufSize: DWORD;
    pResult: pointer;
  begin
  result := '';
  Flags := CRYPT_STRING_BASE64 or CRYPT_STRING_NOCRLF;
  if CryptBinaryToStringW(pointer(S),                    // PBYTE  pbBinary
                          Length(S) * SizeOf(widechar),  // DWORD  cbBinary
                          Flags,                         // DWORD  dwflags
                          nil,                           // LPWSTR pszString
                          NumChars) then                 // PDWORD pcchString
    begin
    BufSize := NumChars * SizeOf(widechar);
    GetMem(pResult, BufSize);
    if CryptBinaryToStringW(pointer(S),                    // PBYTE  pbBinary
                            Length(S) * SizeOf(widechar),  // DWORD  cbBinary
                            Flags,                         // DWORD  dwFlags
                            pResult,                       // LPWSTR pszString
                            NumChars) then                 // PDWORD pcchString
      result := string(pwidechar(pResult));
    FreeMem(pResult, BufSize);
    end;
  end;

function Base64StringToUnicode(const S: string): unicodestring;
  var
    S2: unicodestring;
    ByteCount, BufSize: DWORD;
    pResult: pointer;
  begin
  result := '';
  S2 := StringToUnicodeString(S);
  if CryptStringToBinaryW(pwidechar(S2),       // LPCWSTR pszString
                          Length(S2),          // DWORD   cchString
                          CRYPT_STRING_BASE64, // DWORD   dwFlags
                          nil,                 // PByte   pbBinary
                          ByteCount,           // PDWORD  pcbBinary
                          nil,                 // PDWORD  pdwSkip
                          nil) then            // PDWORD  pdwFlags
    begin
    // Buffer must accommodate terminating null
    BufSize := ByteCount + SizeOf(widechar);
    GetMem(pResult, BufSize);
    if CryptStringToBinaryW(pwidechar(S2),        // LPCWSTR pszString
                            Length(S2),           // DWORD   cchString
                            CRYPT_STRING_BASE64,  // DWORD   dwflags
                            pResult,              // PByte   pbBinary
                            ByteCount,            // PDWORD  pcbBinary
                            nil,                  // PDWORD  pdwSkip
                            nil) then             // PDWORD  pdwFlags
      begin
      // Add null character to end of buffer
      pwidechar(pResult + ByteCount)^ := widechar(#0);
      result := unicodestring(pwidechar(pResult));
      end;
    FreeMem(pResult, BufSize);
    end;
  end;

begin
end.
