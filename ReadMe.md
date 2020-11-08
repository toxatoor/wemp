# WEMP - Nginx/PHP/Mysql for Windows

`wemp.ps1` is a PowerShell script to install Nginx/PHP/Mysql on Windows host with a proper service wrapper, allowing all the stack to run as a windows service. 
It downloads portable versions of apps, unpacks, configures, installs services and allows basic start/stop/restart operations. 
Also it supports `run_debug` mode, runnig all the apps in foregroung in separate cmd windows. 

## Requirements

Known to work on Windows 10 with PowerShell 5.1.17763.1432. Wasn't tested on different versions, might have some issues related to unsupported PowerShell features (e.g. Zip extraction). 

## Usage

Running `./wemp.ps1` shows basic help. 
Default target dir is `C:\WEMP`

- `./wemp.ps1 install`   - downloads and configures apps, installs services. 
- `./wemp.ps1 start`     - starts stack
- `./wemp.ps1 stop`      - stops stack 
- `./wemp.ps1 uninstall` - removes services

After services removed, it's safe to delete whole target dir to remove stack completely. 
 

## Known bugs

As of all the service-related operations performed by [Windows Service Wrapper](https://github.com/winsw/winsw), the exe-file might be treated as "Downloaded from unknown source", therefore Windows might bring the security pop-up on every WinSW invokaton, when running without Administrator privileges. 

## TODO 

- Add graceful mysql shutdown
- Validate source URLs for binaries 
- Better logs handling
- Better permission handling
- Add autoselect for the latest stable version of binaries
- Add support for different applicaton branches
- Add multiple environment support

