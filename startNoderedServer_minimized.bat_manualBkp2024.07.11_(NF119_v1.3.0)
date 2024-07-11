@echo off
if not DEFINED IS_MINIMIZED set IS_MINIMIZED=1 && start "node-red server" /min /D "%userprofile%" "%~dpnx0" %* && exit
cls && node-red