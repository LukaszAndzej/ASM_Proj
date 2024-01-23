doskey
cls
echo off
tasm %1 /l/n
if errorlevel 1 goto end
tlink %1
%1.%exe
:end