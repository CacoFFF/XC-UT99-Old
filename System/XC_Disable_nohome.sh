echo Status previous to uninstallation:
./ucc-bin XC_Setup -nohomedir *engine *netdriver

echo Disabling all components:
./ucc-bin XC_Setup -nohomedir -engine -netdriver
