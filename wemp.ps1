
$cmd=$args[0]
$opt=$args[1]

$install_path=$opt
if ($install_path -eq $null) { 
  $install_path="C:\WEMP"
}

$versions = @{
  nginx = "1.18.0";
  php   = "7.4.12";
  mysql = "5.7.30"; 
  winsw = "v2.10.3";
} 

$tmp = $versions.mysql.ToCharArray()
$mysql_path_ver = "$($tmp[0])$($tmp[1])$($tmp[2])"

$files = @{
  nginx = "nginx-$($versions.nginx).zip";
  php   = "php-$($versions.php)-Win32-vc15-x64.zip";
  mysql = "mysql-$($versions.mysql)-winx64.zip";
  winsw = "WinSW.NET461.exe";
}

$renames = @{
  mysql = "mysql-$($versions.mysql)-winx64";
}

$urls = @{
  nginx = "http://nginx.org/download/$($files.nginx)"; 
  php   = "https://windows.php.net/downloads/releases/$($files.php)"; 
  mysql = "https://mirror.yandex.ru/mirrors/ftp.mysql.com/Downloads/MySQL-$mysql_path_ver/$($files.mysql)"; 
  winsw = "https://github.com/winsw/winsw/releases/download/$($versions.winsw)/$($files.winsw)";
}

$service_config = @{
  nginx = @"
---
id: nginx-$($versions["nginx"])
name: Nginx $($versions["nginx"]) (powered by WinSW)
description: nginx-$($versions["nginx"]) / WEMP stack
executable: nginx.exe

arguments: >
  -g
  "daemon off;"

onFailure:
  - action: restart
    delay: 1 sec

workingdirectory: $install_path\nginx-$($versions["nginx"])
priority: Normal
stopTimeout: 15 sec
stopParentProcessFirst: true 
startMode: Automatic
interactive: false
log:
    logpath: $install_path\logs\nginx-$($versions["nginx"])
    mode: append
"@; 

  php   = @"
---
id: php-$($versions["php"])
name: PHP $($versions["php"]) (powered by WinSW)
description: php-$($versions["php"]) / WEMP stack
executable: php-cgi.exe

arguments: >
  -b 
  127.0.0.1:9000 
  -d 
  error_log=$install_path\logs\php-$($versions["php"])\error.log

onFailure:
  - action: restart
    delay: 1 sec

workingdirectory: $install_path\php-$($versions["php"])
priority: Normal
stopTimeout: 15 sec
stopParentProcessFirst: true 
startMode: Automatic
interactive: false
log:
    logpath: $install_path\logs\php-$($versions["php"])
    mode: append

"@; 

  mysql = @"
id: mysql-$($versions["mysql"])
name: Mysql $($versions["mysql"]) (powered by WinSW)
description: mysql-$($versions["mysql"]) / WEMP stack
executable: bin\mysqld.exe

arguments: >
  --defaults-file=$install_path\mysql-$($versions["mysql"])\my.cnf
  --standalone

onFailure:
  - action: restart
    delay: 1 sec

workingdirectory: $install_path\mysql-$($versions["mysql"])
priority: Normal
stopTimeout: 15 sec
stopParentProcessFirst: true 
startMode: Automatic
interactive: false
log:
    logpath: $install_path\logs\mysql-$($versions["mysql"])
    mode: append
"@;
}


$help = @"
This is help 

Usage: wemp.ps1 command [target_dir]

Default Target dir: $install_path    

Main Commands: 

install         - { download ; unpack; configure; install_service }
uninstall       - Removes installed windows services, leaving $install_path intact

Stage commands:

download        - Downloads
unpack          - Downloads and unpacks
configure       - Downloads, unpacks and configures
install_service - Downloads, unpacks, configures and installs windows service

Operation commands:

start           - Starts stack
stop            - Stops stack 
restart         - { stop ; start } 

run_debug       - Runs the stack as CLI apps, in foreground, in separate console 
                  windows without installing windows service

Setup: 
mysql = $($versions.mysql)`t $($urls.mysql)
nginx = $($versions.nginx)`t $($urls.nginx)
php   = $($versions.php)`t $($urls.php)
winsw = $($versions.winsw)`t $($urls.winsw)


"@ 

function ShowHelp {
  write-host $help
} 

function Download  { 
  write-host "Downloading to $install_path\dist" 
  if ( -not (Test-Path $install_path) ) { " Install path $install_path does not exist, creating..."; New-Item -ItemType Directory -Path $install_path > $null }
  if ( -not (Test-Path $install_path\dist ) ) { New-Item -ItemType Directory -Path $install_path\dist > $null }
  foreach ( $app in $versions.Keys ) { 
    if ( -not (Test-Path $install_path\dist\$($files[$app]) )) { 
      " Distr file $($files[$app]) does not exist, downloading from $($urls[$app])..." 
      Invoke-WebRequest -Uri $($urls[$app]) -OutFile $install_path\dist\$($files[$app])
    }
  }
} 

function Unpack {
  write-host "Unpacking apps..."
  foreach ($app in "php" ) { 
    if ( -not (Test-Path $install_path\$app-$($versions[$app]) ) ) { 
      Expand-Archive -Path $install_path\dist\$($files[$app]) -DestinationPath $install_path\$app-$($versions[$app])
    } else { " $app exists, skipping unpack..." } 
  } 
  
  foreach ($app in "nginx", "mysql") { 
    if ( -not (Test-Path $install_path\$app-$($versions[$app]) ) ) { 
      Expand-Archive -Path $install_path\dist\$($files[$app]) -DestinationPath $install_path
    } else { " $app exists, skipping unpack..." } 
  } 

  foreach ($app in  $renames.Keys ) {
    if ( -not (Test-Path $install_path\$app-$($versions[$app]) ) ) { 
      Rename-Item -Path $install_path\$($renames[$app]) -NewName $install_path\$app-$($versions[$app])
    } else { " $app exists, skipping rename..." } 
  } 
   
}

function Configure {

  if ( -not (Test-Path $install_path\logs ) ) { " Log path $install_path\logs does not exist, creating..."; New-Item -ItemType Directory -Path $install_path\logs > $null }
  foreach ($app in "php", "nginx", "mysql") { 
    if ( -not (Test-Path $install_path\logs\$app-$($versions[$app]) )) { 
      " Log path $install_path\logs\$app-$($versions[$app]) does not exist, creating..."; New-Item -ItemType Directory -Path $install_path\logs\$app-$($versions[$app]) > $null
    } 
  }

# Place nginx config 

if ( -not (Test-Path $install_path\nginx-$($versions["nginx"])\conf.d) ) { New-Item -ItemType Directory -Path $install_path\nginx-$($versions["nginx"])\conf.d > $null } 

$install_path_nginx = $( $install_path -replace "\\", "/" )

$nginx_conf = @"
worker_processes  auto;
error_log  $install_path_nginx/logs/nginx-$($versions["nginx"])/error.log ; 
pid        $install_path_nginx/logs/nginx-$($versions["nginx"])/nginx.pid ; 

worker_rlimit_nofile 32768 ;

events {
    worker_connections  32768 ;
}

http {
    include       $install_path_nginx/nginx-$($versions["nginx"])/conf/mime.types ;
    default_type  text/plain ; 

    log_format  main  '`$remote_addr - `$remote_user [`$time_local] "`$request" '
                      '`$status `$body_bytes_sent "`$http_referer" '
                      '"`$http_user_agent" "`$http_x_forwarded_for" `$http_host `$request_time ';

    access_log  $install_path_nginx/logs/nginx-$($versions["nginx"])/access.log main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  3;

    #gzip  on;

    client_max_body_size            1m;

    proxy_buffer_size 64k;
    proxy_buffers 4 128k;
    proxy_busy_buffers_size 128k;

    include $install_path_nginx/nginx-$($versions["nginx"])/conf.d/*.conf ; 
}
"@; 

$default_conf = @"
server {
    listen          80 ; 
    server_name     default ; 
    root            $install_path_nginx/sites/default; 
   
    access_log      $install_path_nginx/logs/nginx-$($versions["nginx"])/default-access.log main ; 
    error_log       $install_path_nginx/logs/nginx-$($versions["nginx"])/default-error.log ;


    gzip_min_length  1024;
    gzip_types       application/javascript application/x-javascript text/css ;

    location / { 
        index        index.html index.php ; 
    }

    location ~* ^.+\.php$ {
        
        fastcgi_pass   127.0.0.1:9000 ; 
        fastcgi_index  index.php;
        fastcgi_intercept_errors on;

        fastcgi_param  SCRIPT_FILENAME  `$document_root`$fastcgi_script_name;
        fastcgi_param  DOCUMENT_ROOT    `$document_root;
        include fastcgi_params;
    }


}
"@;

Out-File -FilePath $install_path\nginx-$($versions["nginx"])\conf\nginx.conf -InputObject $nginx_conf -Encoding ASCII
Out-File -FilePath $install_path\nginx-$($versions["nginx"])\conf.d\default.conf -InputObject $default_conf -Encoding ASCII


## default site
if ( -not (Test-Path $install_path\sites) ) { New-Item -ItemType Directory -Path $install_path\sites > $null } 
if ( -not (Test-Path $install_path\sites\default) ) { New-Item -ItemType Directory -Path $install_path\sites\default > $null } 
Out-File -FilePath $install_path\sites\default\index.php -InputObject "<?php phpinfo(); ?>" -Encoding ASCII


# Place mysql config 
$mysql_conf = @"
[client]
port            = 3306

[mysqld_safe]
nice            = 0

[mysqld]
pid-file        = $install_path\logs\mysql-$($versions["mysql"])\mysql.pid
port            = 3306
basedir         = $install_path\mysql-$($versions["mysql"])
datadir         = $install_path\mysql-$($versions["mysql"])\data
tmpdir          = $install_path

skip-external-locking
bind-address            = 0.0.0.0
max_allowed_packet      = 16M
thread_stack            = 192K
thread_cache_size       = 64

tmp_table_size=128M
max_heap_table_size=64M
join_buffer_size=128M
sort_buffer_size=128M

innodb_table_locks=0
skip-external-locking

query_cache_size=256M
query_cache_limit=8M
query_cache_min_res_unit=2048

log_error               = $install_path\logs\mysql-$($versions["mysql"])\mysql.log

server-id = 101
report-host = mysql

innodb_buffer_pool_size   = 1G
innodb_log_buffer_size    = 4M
innodb_thread_concurrency = 8
innodb_file_per_table

[mysqldump]
quick
quote-names
max_allowed_packet      = 16M

[mysql]

[isamchk]
key_buffer              = 16M

"@; 

Out-File -FilePath $install_path\mysql-$($versions["mysql"])\my.cnf -InputObject $mysql_conf -Encoding ASCII

if ( -not (Test-Path $install_path\mysql-$($versions["mysql"])\data )) { New-Item -ItemType Directory -Path $install_path\mysql-$($versions["mysql"])\data > $null }
if ( -not (Test-Path $install_path\mysql-$($versions["mysql"])\data\ibdata1 )) { 
  " Mysql database does not exist, initializing..."
  & $install_path\mysql-$($versions["mysql"])\bin\mysqld.exe --defaults-file=$install_path\mysql-$($versions["mysql"])\my.cnf --initialize-insecure
  } 

}

function InstallService { 
  write-host "Installing windows services..."
  foreach ($app in "php", "nginx", "mysql") { 
    if ( -not (Test-Path $install_path\$app-$($versions[$app])\winsw.exe )) { 
      Copy-Item $install_path\dist\$($files["winsw"]) -Destination $install_path\$app-$($versions[$app])\winsw.exe
    } 
    Out-File -FilePath $install_path\$app-$($versions[$app])\winsw.yml -InputObject $($service_config[$app]) -Encoding ASCII 
    & $install_path\$app-$($versions[$app])\winsw.exe install
  }
} 

function Uninstall { 
  write-host "Uninstalling windows services..."
  foreach ($app in "php", "nginx", "mysql") { 
    & $install_path\$app-$($versions[$app])\winsw.exe uninstall
  }
}

function RunDebug {
  cmd /C start /D $install_path\nginx-$($versions["nginx"]) nginx.exe -g 'daemon off;'
  cmd /C start /D $install_path\php-$($versions["php"]) php-cgi.exe -b 127.0.0.1:9000
  cmd /C start /D $install_path\mysql-$($versions["mysql"]) bin\mysqld.exe --defaults-file=$install_path\mysql-$($versions["mysql"])\my.cnf --standalone
} 

function StartStack { 
  foreach ($app in "php", "nginx", "mysql") {
    write-host "Starting $app service..."
    & $install_path\$app-$($versions[$app])\winsw.exe start
  }  
}

function StopStack { 
  foreach ($app in "php", "nginx", "mysql") {
    write-host "Starting $app service..."
    & $install_path\$app-$($versions[$app])\winsw.exe stop
  }  
}

Switch ($cmd)
{
    "install"         { Download ; Unpack ; Configure ; InstallService } 
    "download"        { Download }
    "unpack"          { Download ; Unpack }
    "configure"       { Download ; Unpack ; Configure } 
    "install_service" { Download ; Unpack ; Configure ; InstallService } 
    "uninstall"       { Uninstall }
    "run_debug"       { RunDebug }
    "start"           { StartStack }
    "stop"            { StopStack }
    "restart"         { StopStack ; StartStack }
    default           { ShowHelp } 
}
