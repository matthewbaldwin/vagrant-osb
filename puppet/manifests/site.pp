#
# one machine setup with OSB plus weblogic 10.3.6 patched to PS 6
#
# 
#
# needs  oradb, jdk7, wls, orautils, fiddyspence-sysctl, erwbgy-limits puppet modules
#

node 'vagrantcentos64' {

   include os2, wls1036, orautils
   Class['os2'] -> Class['wls1036'] -> Class['orautils'] 

}

# operating settings for Middleware
class os2 {

  notify{"wls12 node":}

  $remove = [ "java-1.7.0-openjdk.x86_64", "java-1.6.0-openjdk.x86_64" ]

  package { $remove:
    ensure  => absent,
  }

  $install = [ 'binutils.x86_64','unzip.x86_64']

  package { $install:
    ensure  => present,
  }

  include jdk7

  jdk7::install7{ 'jdk1.7.0_45':
     version              => "7u45", 
      fullVersion          => "jdk1.7.0_45",
      alternativesPriority => 17000, 
      x64                  => true,
      downloadDir          => "/vagrant",
      urandomJavaFix       => true,
      sourcePath           => "/vagrant"
  }

  class { 'limits':
    config => {
               '*'       => { 'nofile'   => { soft => '2048'   , hard => '8192',   },},
               'oracle'  => {  'nofile'  => { soft => '65536'  , hard => '65536',  },
                               'nproc'   => { soft => '2048'   , hard => '16384',   },
                               'memlock' => { soft => '1048576', hard => '1048576',},
                               'stack'   => { soft => '10240'  ,},},
               },
    use_hiera => false,
  }

  sysctl { 'kernel.msgmnb':                 ensure => 'present', permanent => 'yes', value => '65536',}
  sysctl { 'kernel.msgmax':                 ensure => 'present', permanent => 'yes', value => '65536',}
  sysctl { 'kernel.shmmax':                 ensure => 'present', permanent => 'yes', value => '2588483584',}
  sysctl { 'kernel.shmall':                 ensure => 'present', permanent => 'yes', value => '2097152',}
  sysctl { 'fs.file-max':                   ensure => 'present', permanent => 'yes', value => '6815744',}
  sysctl { 'net.ipv4.tcp_keepalive_time':   ensure => 'present', permanent => 'yes', value => '1800',}
  sysctl { 'net.ipv4.tcp_keepalive_intvl':  ensure => 'present', permanent => 'yes', value => '30',}
  sysctl { 'net.ipv4.tcp_keepalive_probes': ensure => 'present', permanent => 'yes', value => '5',}
  sysctl { 'net.ipv4.tcp_fin_timeout':      ensure => 'present', permanent => 'yes', value => '30',}
  sysctl { 'kernel.shmmni':                 ensure => 'present', permanent => 'yes', value => '4096', }
  sysctl { 'fs.aio-max-nr':                 ensure => 'present', permanent => 'yes', value => '1048576',}
  sysctl { 'kernel.sem':                    ensure => 'present', permanent => 'yes', value => '250 32000 100 128',}
  sysctl { 'net.ipv4.ip_local_port_range':  ensure => 'present', permanent => 'yes', value => '9000 65500',}
  sysctl { 'net.core.rmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
  sysctl { 'net.core.rmem_max':             ensure => 'present', permanent => 'yes', value => '4194304', }
  sysctl { 'net.core.wmem_default':         ensure => 'present', permanent => 'yes', value => '262144',}
  sysctl { 'net.core.wmem_max':             ensure => 'present', permanent => 'yes', value => '1048576',}

  exec { "create swap file":
    command => "/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=8192",
    creates => "/var/swap.1",
  }
 
  exec { "attach swap file":
    command => "/sbin/mkswap /var/swap.1 && /sbin/swapon /var/swap.1",
    require => Exec["create swap file"],
    unless => "/sbin/swapon -s | grep /var/swap.1",
  }
  
  #add swap file entry to fstab
  exec {"add swapfile entry to fstab":
    command => "/bin/echo >>/etc/fstab /var/swap.1 swap swap defaults 0 0",
    require => Exec["attach swap file"],
    user => root,
    unless => "/bin/grep '^/var/swap.1' /etc/fstab 2>/dev/null",
  }

  service { iptables:
        enable    => false,
        ensure    => false,
        hasstatus => true,
  }

 
}

class wls1036{

  $jdkWls11gJDK = 'jdk1.7.0_45'
  $wls11gVersion = "1036"
                      
  $puppetDownloadMntPoint = "/vagrant"

  $osOracleHome = "/opt/oracle"
  $osMdwHome    = "/opt/oracle/wls/Middleware11gR1"
  $osWlHome     = "/opt/oracle/wls/Middleware11gR1/wlserver_10.3"
  $user         = "oracle"
  $group        = "dba"
  $downloadDir  = "/data/install"
  $logDir       = "/data/logs"

  $wlsDomainName   = "osbDomain"
  $osTemplate      = "osb"
  $adminListenPort = "7001"
  $nodemanagerPort = "5556"
  $address         = "localhost"
  $wlsUser         = "weblogic"
  $password        = "welcome1"   

  class{'orautils':
    osOracleHomeParam      => $osOracleHome,
    oraInventoryParam      => "${osOracleHome}/oraInventory",
    osDomainTypeParam      => "admin",
    osLogFolderParam       => $logDir,
    osDownloadFolderParam  => $downloadDir,
    osMdwHomeParam         => $osMdwHome,
    osWlHomeParam          => $osWlHome,
    oraUserParam           => $user,
    osDomainParam          => $wlsDomainName,
    osDomainPathParam      => "${osMdwHome}/user_projects/domains/${wlsDomainName}",
    nodeMgrPathParam       => "${osMdwHome}/wlserver_10.3/server/bin",
    nodeMgrPortParam       => 5556,
    wlsUserParam           => $wlsUser,
    wlsPasswordParam       => $password,
    wlsAdminServerParam    => "AdminServer",
  } 


  # set the defaults
  Wls::Installwls {
    version                => $wls11gVersion,
    fullJDKName            => $jdkWls11gJDK,
    oracleHome             => $osOracleHome,
    mdwHome                => $osMdwHome,
    user                   => $user,
    group                  => $group,    
    downloadDir            => $downloadDir,
    puppetDownloadMntPoint => $puppetDownloadMntPoint,
  }

  Wls::Installosb {
    mdwHome                => $osMdwHome,
    wlHome                 => $osWlHome,
    oracleHome             => $osOracleHome,
    fullJDKName            => $jdkWls11gJDK,        
    user                   => $user,
    group                  => $group,    
    downloadDir            => $downloadDir,
    puppetDownloadMntPoint => $puppetDownloadMntPoint, 
  }

  Wls::Nodemanager {
    wlHome       => $osWlHome,
    fullJDKName  => $jdkWls11gJDK,        
    user         => $user,
    group        => $group,
    serviceName  => $serviceName,  
    downloadDir  => $downloadDir, 
  }

  Wls::Bsupatch {
    mdwHome                => $osMdwHome,
    wlHome                 => $osWlHome,
    fullJDKName            => $jdkWls11gJDK,
    user                   => $user,
    group                  => $group,
    downloadDir            => $downloadDir, 
    puppetDownloadMntPoint => $puppetDownloadMntPoint, 
  }

  # install
  wls::installwls{'11g1036':
    # create the user and group here if we creates db after it will use these vaules
    createUser   => true, 
  }
  
  # weblogic patch Patchset 6 (October 2013)
  wls::bsupatch{'p17071663':
     patchId      => 'BYJ1',    
     patchFile    => 'p17071663_1036_Generic.zip',  
     require      => Wls::Installwls['11g1036'],
  }

  wls::installosb{'osbPS6':
    osbFile      => 'ofm_osb_generic_11.1.1.7.0_disk1_1of1.zip',
    require      => Wls::Bsupatch['p17071663'],
  }

  #nodemanager configuration and starting
  wls::nodemanager{'nodemanager11g':
    listenPort  => '5556',
    logDir      => $logDir,
    require     => Wls::Installosb['osbPS6'],
  }


  wls::wlsdomain{'osbDomain':
    wlHome          => $osWlHome,
    mdwHome         => $osMdwHome,
    fullJDKName     => $jdkWls11gJDK, 
    wlsTemplate     => $osTemplate,
    domain          => $wlsDomainName,
    adminServerName => "AdminServer",
    adminListenAdr  => "localhost",
    adminListenPort => $adminListenPort,
    nodemanagerPort => $nodemanagerPort,
    wlsUser         => $wlsUser,
    password        => $password,
    user            => $user,
    group           => $group,    
    logDir          => $logDir,
    downloadDir     => $downloadDir, 
    require         => Wls::Nodemanager['nodemanager11g'],
  }

  # start AdminServers for configuration
  wls::wlscontrol{'startOSBSOAAdminServer':
   wlsDomain     => $wlsDomainName,
   wlsDomainPath => "${osMdwHome}/user_projects/domains/${wlsDomainName}",
   wlsServer     => "AdminServer",
   action        => 'start',
   wlHome        => $osWlHome,
   fullJDKName   => $jdkWls11gJDK,  
   wlsUser       => $wlsUser,
   password      => $password,
   address       => $address,
   port          => $nodemanagerPort,
   user          => $user,
   group         => $group,
   downloadDir   => $downloadDir,
   logOutput     => true, 
   require       => Wls::Wlsdomain['osbDomain'],
  }

  # create keystores for automatic WLST login
  wls::storeuserconfig{
   'osbSoaDomain_keys':
    wlHome        => $osWlHome,
    fullJDKName   => $jdkWls11gJDK,
    domain        => $wlsDomainName, 
    address       => $address,
    wlsUser       => "weblogic",
    password      => "welcome1",
    port          => $adminListenPort,
    user          => $user,
    group         => $group,
    userConfigDir => $userConfigDir, 
    downloadDir   => $downloadDir, 
    require       => Wls::Wlscontrol['startOSBSOAAdminServer'],
  }

   
  orautils::nodemanagerautostart{"autostart ${wlsDomainName}":
    version     => "1111",
    wlHome      => $osWlHome, 
    user        => $user,
    require     => Wls::Nodemanager['nodemanager11g'];
  }


}




