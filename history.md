# editenv Version History

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
