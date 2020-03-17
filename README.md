# editenv - Written by Bill Stewart (bstewart at iname.com)

This is free software and comes with ABSOLUTELY NO WARRANTY.

## SYNOPSIS

**editenv** is a Windows console program that lets you interactively edit the value
of an environment variable.

## USAGE

**editenv** [_parameter_ [...]] _variablename_

| Parameter                  | Abbrev.     | Description
| -------------------------- | ----------- | ------------------------------------------------
| **--allowedchars=**...     | **-a** ...  | Only allows input of specified characters
| **--beginningofline**      | **-b**      | Starts cursor at beginning of line
| **--disallowchars=**...    | **-D** ...  | Disallows input of specified characters
| **--disallowquotes**       | **-d**      | Disallows input of `"` character
| **--emptyinputallowed**    | **-e**      | Empty input is allowed to remove variable
| **--help**                 | **-h**      | Displays usage information
| **--limitlength=**_n_      | **-l** _n_  | Limits length of typed input to _n_ character(s)
| **--maskinput**[**=**_x_]  | **-m** _x_  | Masks input using character _x_ (default=`*`)
| **--overtypemode**         | **-o**      | Starts line editor in overtype mode
| **--prompt=**...           | **-p** ...  | Specifies an input prompt
| **--quiet**                | **-q**      | Suppresses error messages
| **--timeout=**_n_          | **-t** _n_  | Automatically enter input after _n_ second(s)

Parameter names are case-sensitive.

## LINE EDITOR

The line editor supports the following keystroke commands:

| Key                       | Action
| ------------------------- | ------------------------------------------------
| `Left`, `Right`           | Moves cursor left or right
| `Home` or `Ctrl+A`        | Moves cursor to beginning of line
| `End` or `Ctrl+E`         | Moves cursor to end of line
| `Ctrl+Left`, `Ctrl+Right` | Moves cursor left or right one word
| `Insert`                  | Toggle between insert and overtype mode
| `Delete`                  | Deletes the character under the cursor
| `Backspace` or `Ctrl+H`   | Deletes the character to the left of the cursor
| `Ctrl+Home`               | Deletes to the beginning of the line
| `Ctrl+End`                | Deletes to the end of the line
| `Esc` or `Ctrl+[`         | Deletes the entire line
| `Ctrl+U` or `Ctrl+Z`      | Reverts line to original value
| `Ctrl+C`                  | Cancel input
| `Enter` or `Ctrl+M`       | Enter input

* There is no visual indication of insert vs. overtype mode.

* **editenv** does not work from the PowerShell ISE.

## EXIT CODES

| Description                                               | Exit Code
| --------------------------------------------------------- | ---------
| No error                                                  | 0
| Empty input and **--emptyinputallowed** not specified     | 13
| Command line contains an error                            | 87
| Environment variable name or value are too long           | 122
| Cannot use **--maskinput** parameter when variable exists | 183
| Current and parent process must both be 32-bit or 64-bit  | 216
| **--timeout** period elapsed                              | 258
| `Ctrl+C` pressed to cancel input                          | 1223

* In cmd.exe, you can check the exit code using the `%ERRORLEVEL%` variable or
  the `if errorlevel` command.

* In PowerShell, you can check the exit code using the `$LASTEXITCODE`
  variable.

## LIMITATIONS

* The environment variable's name cannot contain the `=` character.

* The environment variable's name is limited to 127 characters.

* The environment variable's value is limited to 16383 characters.

* The `--timeout` parameter does not use a high-precision timer.

* The `--maskinput` parameter is not encrypted or secure.

## EXAMPLES

1.  Edit the `Path` environment variable for the current console:

        editenv Path

    When you enter this command, `editenv` lets you interactively edit the
    `Path` environment variable for the current console process.

2.  cmd.exe shell script (batch file):

        @echo off
        setlocal enableextensions
        :REPEAT
        set _NAME=%USERNAME%
        editenv --prompt="Enter your name: " --quiet _NAME
        if %ERRORLEVEL% EQU 1223 goto :CANCEL
        if %ERRORLEVEL% EQU 13 goto :NOEMPTY
        echo Hello, %_NAME%
        goto :DONE
        :CANCEL
        echo You canceled
        goto :DONE
        :NOEMPTY
        echo You didn't enter your name
        goto :REPEAT
        :DONE
        endlocal

    This script prompts you to enter your name and uses the value of the
    `%USERNAME%` environment variable as the initial value. If you press
    `Ctrl+C`, the script outputs "You canceled". If you pressed `Enter` on an
    empty input line, the script outputs "You didn't enter your name" and
    repeats the prompt.

3.  cmd.exe shell script:

        @echo off
        setlocal enableextensions
        :REPEAT
        set _PIN=
        editenv --allowedchars=0123456789 --limitlength=8 --maskinput --prompt="PIN: " --quiet _PIN
        if %ERRORLEVEL% EQU 1223 goto :REPEAT
        if %ERRORLEVEL% EQU 13 goto :REPEAT
        echo You entered: %_PIN%
        endlocal

    This script prompts you to enter up to an 8-digit number. Pressing `Ctrl+C`
    or pressing `Enter` without entering a value repeats the prompt.

4.  PowerShell script:

        $env:_ANS = "N"
        do {
          editenv --prompt="Are you sure? [Y/N] " --allowedchars=NnYy --beginningofline --limitlength=1 --overtype --quiet --timeout=20 _ANS
        } until ( $LASTEXITCODE -ne 13 )
        if ( $LASTEXITCODE -ne 1223 ) {
          if ( $env:_ANS -eq "Y" ) {
            "You said yes"
          }
          else {
            "You said no"
          }
        }
        $env:_ANS = $null

    This script presents a timed prompt to enter a `Y` or `N` answer. If you
    don't enter anything within 20 seconds, `N` is assumed. Otherwise, you can
    enter a `Y` or `N` response. If you enter empty input, the prompt repeats.
    Pressing `Ctrl+C` skips the output statements.
