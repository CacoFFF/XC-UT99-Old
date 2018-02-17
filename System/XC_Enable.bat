@echo off
cls

echo Status previous to installation:
ucc XC_Setup -nohomedir *engine *netdriver *editor

echo Enabling all components:
ucc XC_Setup -nohomedir +engine +netdriver +editor
