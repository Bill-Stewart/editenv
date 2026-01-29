# EditEnv Version History

## 2.0.1 (2025-01-29)

* Added application manifest to executable resource to enforce UTF-8 encoding on Windows 10 version 1903 and later.

* Minor tweaks.

## 2.0.0 (2025-04-17)

* Added Unicode support. For best results, use UTF8 encoding in the console as noted in the **Unicode Support** section of the documentation.

* Added **Ctrl+V**/**Shift+Insert** to paste clipboard contents.

* Rather than being ignored, **Ctrl+Break** keystroke now cancels the same as **Ctrl+C**.

* Changed the **--disallowchars** parameter's abbreviated option from **-D** to **-d** to align better with other parameters.

* Removed the **--disallowquotes** parameter (formerly **-d**) as it's no longer needed. To prevent entry of the `"` character, quote the argument to the **--disallowchars** (**-d**) parameter and specify the `"` character by doubling it inside the quoted string (e.g., `-d "a""bc"` disallows entry of the following characters: `a`, `"`, `b`, and `c`).

* Improved Windows Terminal (WT) detection: Rather than checking if the **WT_SESSION** environment variable is defined, **EditEnv** checks if WindowsTerminal.exe is running in the current process tree. There's still the limitation that you can't edit a string that's longer than what will fit in the WT window. Currently there's no workaround for this limitation in WT. (The native Windows console does not have this limitation.)

* Added PowerShell ISE detection: **EditEnv** now aborts with exit code 6 if the parent process is the PowerShell ISE.

* Improved cursor movement and positioning if the window is resized while **EditEnv** is running. There are likely some remaining issues regarding window resizing, so it's still recommended not to resize the console window while **EditEnv** is running.

* Implemented numerous other tweaks and fixes.

## 1.6.2 (2023-01-19)

* Minor tweaks and bump version number for release redistributable.

## 1.6.1 (2021-11-03)

* Added support to detect the maximum possible number of input characters. In a Windows Terminal (WT) session, maximum input length is currently limited to the current screenful (i.e., you can't edit an environment variable that has a value longer than the current screenful). The **--getmaxlength** parameter reports the maximum possible number of input characters.

## 1.6.0 (2021-06-18)

* Corrected character code page conversions when reading the command line and updating the environment variable in the parent process. (It's important to note that not all characters can be converted correctly.)

* Updated the **--allowedchars** (**-a**) and **--disallowchars** (**-D**) parameters to require arguments containing only 7-bit ASCII characters (characters outside of this range create problems for code page conversions).

* Added version number to usage output.

* Minor tweaks.

## 1.5.0 (2021-06-17)

* Added **--minlength** (**-n**) parameter.

* Changed **--limitlength** (**-l**) to **--maxlength** (**-x**) for consistency with **--minlength** (**-n**). For backward compatibility, **--limitlength** (**-l**) is still accepted but deprecated and may be removed in the future.

* Updated internal functions to use Unicode strings.

* Updated code formatting to improve readability.

* Expanded documentation.

* Build using FPC 3.2.2.

* Minor tweaks.

## 1.1.0 (2020-07-13)

* Build using FPC 3.2.0.

* Minor documentation corrections.

## 1.0.0 (2020-03-17)

* Initial version.
