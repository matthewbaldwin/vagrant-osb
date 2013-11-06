#
# one machine setup with 11g XE database plus weblogic 10.3.6 patched to PS 6
#
# 
#
# needs  oradb, jdk7, wls, orautils, fiddyspence-sysctl, erwbgy-limits puppet modules
#

node 'vagrantcentos64' {
  
   # include os2, db12c2, wls12_adf2, wls12c_adf_domain2, orautils, maintenance
   include os2, wls1036, orautils
   
   # Class['os2'] -> Class['wls12_adf2'] -> Class['db12c2'] -> Class['wls12c_adf_domain2'] -> Class['maintenance']

   Class['os2'] -> Class['wls1036'] -> Class['orautils'] 

}

# operating settings for Database & Middleware
class os2 {

  notify{"wls12 node":}

  $remove = [ "java-1.7.0-openjdk.x86_64", "java-1.6.0-openjdk.x86_64" ]

  package { $remove:
    ensure  => absent,
  }

  $install = [ 'binutils.x86_64', 'compat-libstdc++-33.x86_64', 'glibc.x86_64','ksh.x86_64','libaio.x86_64',
               'libgcc.x86_64', 'libstdc++.x86_64', 'make.x86_64','compat-libcap1.x86_64', 'gcc.x86_64',
               'gcc-c++.x86_64','glibc-devel.x86_64','libaio-devel.x86_64','libstdc++-devel.x86_64',
               'sysstat.x86_64','unixODBC-devel','glibc.i686','bc.x86_64', 'unzip.x86_64']
               
               
  package { $install:
    ensure  => present,
  }

include jdk7

  jdk7::install7{ 'jdk1.7.0_45':
     version              => "7u45" , 
      fullVersion          => "jdk1.7.0_45",
      alternativesPriority => 17000, 
      x64                  => true,
      # downloadDir          => "/data/install",
      downloadDir          => "/vagrant",
      urandomJavaFix       => false,
      # sourcePath           => "puppet:///modules/jdk7/"
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

 
}

class wls1036{


   class { 'wls::urandomfix' :}

   $jdkWls11gJDK = 'jdk1.7.0_45'
   $wls11gVersion = "1036"
                       
#  $puppetDownloadMntPoint = "puppet:///middleware/"
   #$puppetDownloadMntPoint = "puppet:///modules/wls/" 
   $puppetDownloadMntPoint = "/vagrant"                      
 
   $osOracleHome = "/opt/oracle"
   $osMdwHome    = "/opt/oracle/wls/Middleware11gR1"
   $osWlHome     = "/opt/oracle/wls/Middleware11gR1/wlserver_10.3"
   $user         = "oracle"
   $group        = "dba"
   $downloadDir  = "/data/install"
   $logsDir      = "/data/logs"

   $wlsDomainName   = "osbDomain"
   $osTemplate      = "osb"
   $adminListenPort = "7001"
   $nodemanagerPort = "5556"
   $address         = "localhost"
   $wlsUser         = "weblogic"
   $password        = "welcome1"   

  case $operatingsystem {
    CentOS, RedHat, OracleLinux, Ubuntu, Debian: { 
      $mtimeParam = "1"
    }
    Solaris: { 
      $mtimeParam = "+1"
    }
  }

  case $operatingsystem {
    CentOS, RedHat, OracleLinux, Ubuntu, Debian, Solaris: { 

                  cron { 'cleanwlstmp' :
                    command => "find /tmp -name '*.tmp' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/tmp_purge.log 2>&1",
                    user    => oracle,
                    hour    => 06,
                    minute  => 25,
                  }
                 
                  #cron { 'mdwlogs' :
                  #  command => "find ${osMdwHome}/logs -name 'wlst_*.*' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/wlst_purge.log 2>&1",
                  #  user    => oracle,
                  #  hour    => 06,
                  #  minute  => 30,
                  #}
                 
                 # cron { 'oracle_common_lsinv' :
                 #   command => "find ${osMdwHome}/oracle_common/cfgtoollogs/opatch/lsinv -name 'lsinventory*.txt' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/opatch_lsinv_common_purge.log 2>&1",
                 #   user    => oracle,
                 #   hour    => 06,
                 #   minute  => 31,
                 # }
                 
                 #cron { 'oracle_osb1_lsinv' :
                 #   command => "find ${osMdwHome}/Oracle_OSB1/cfgtoollogs/opatch/lsinv -name 'lsinventory*.txt' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/opatch_lsinv_osb1_purge.log 2>&1",
                 #   user    => oracle,
                 #   hour    => 06,
                  #  minute  => 32,
                 # }
                 
                  #cron { 'oracle_soa1_lsinv' :
                  #  command => "find ${osMdwHome}/Oracle_SOA1/cfgtoollogs/opatch/lsinv -name 'lsinventory*.txt' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/opatch_lsinv_soa1_purge.log 2>&1",
                  #  user    => oracle,
                  #  hour    => 06,
                  #  minute  => 33,
                  #}
                 
                  #cron { 'oracle_common_opatch' :
                  #  command => "find ${osMdwHome}/oracle_common/cfgtoollogs/opatch -name 'opatch*.log' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/opatch_common_purge.log 2>&1",
                  #  user    => oracle,
                  #  hour    => 06,
                  #  minute  => 34,
                  #}
                 
                  #cron { 'oracle_osb1_opatch' :
                  #  command => "find ${osMdwHome}/Oracle_OSB1/cfgtoollogs/opatch -name 'opatch*.log' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/opatch_osb_purge.log 2>&1",
                  #  user    => oracle,
                  #  hour    => 06,
                  #  minute  => 35,
                  #}
                 
                  #cron { 'oracle_soa1_opatch' :
                  #  command => "find ${osMdwHome}/Oracle_SOA1/cfgtoollogs/opatch -name 'opatch*.log' -mtime ${mtimeParam} -exec rm {} \\; >> /tmp/opatch_soa_purge.log 2>&1",
                  #  user    => oracle,
                  #  hour    => 06,
                  #  minute  => 35,
                  #}


    }

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
    wlsUser         => "weblogic",
    password        => "welcome1",
    user            => $user,
    group           => $group,    
    logDir          => "/data/logs",
    downloadDir      => $downloadDir, 
    require         => Wls::Installosb['osbPS6'],
 }

 # start AdminServers for configuration
  wls::wlscontrol{'startOSBSOAAdminServer':
   wlsDomain     => $wlsDomainName,
   wlsDomainPath => "${osMdwHome}/user_projects/domains/${wlsDomainName}",
   wlsServer     => "AdminServer",
   action        => 'start',
   wlHome        => $osWlHome,
   fullJDKName   => $jdkWls11gJDK,  
   wlsUser       => "weblogic",
   password      => "welcome1",
   address       => $address,
   port          => $nodemanagerPort,
   user          => $user,
   group         => $group,
   downloadDir   => $downloadDir,
   logOutput     => true, 
   # require       =>  Wls::Wlsdomain['osbDomain'],
   require       => Wls::Nodemanager['nodemanager11g'],
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

  # set the defaults
  # Wls::Changefmwlogdir {
  #  mdwHome        => $osMdwHome,
  #  user           => $user,
  #  group          => $group,
  #  address        => $address,
  #  port           => $adminListenPort,
  #  userConfigFile => "${userConfigDir}/${user}-osbSoaDomain-WebLogicConfig.properties",
  #  userKeyFile    => "${userConfigDir}/${user}-osbSoaDomain-WebLogicKey.properties", 
  #  downloadDir    => $downloadDir, 
  #}

 # change the FMW logfiles
  # wls::changefmwlogdir{
  # 'AdminServer':
  #  wlsServer    => "AdminServer",
  #  logDir       => "/data/logs",
  #  require      => Wls::Storeuserconfig['osbSoaDomain_keys'],
  # }


  #nodemanager configuration and starting
   wls::nodemanager{'nodemanager11g':
     listenPort  => '5556',
     # logDir      => "/data/logs",
     require     => Wls::Wlsdomain['osbDomain'],
   }
   
   orautils::nodemanagerautostart{"autostart ${wlsDomainName}":
      version     => "1111",
      wlHome      => $osWlHome, 
      user        => $user,
      # logDir   => "/data/logs",
      require     => Wls::Nodemanager['nodemanager11g'];
   }


}




