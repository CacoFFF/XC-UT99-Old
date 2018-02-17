@echo off
cls

echo Status previous to uninstallation:
ucc XC_Setup -nohomedir *engine *netdriver *editor

echo Disabling all components:
ucc XC_Setup -nohomedir -engine -netdriver -editor
