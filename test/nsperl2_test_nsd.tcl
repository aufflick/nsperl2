global env
set home $env(NSINST)
set nsperl2TestHome [file dirname [ns_info config]]
set pageRoot $nsperl2TestHome/pages


ns_section "ns/parameters"
    ns_param home $home
    ns_param logdebug true

ns_section "ns/mimetypes"
    ns_param default "*/*"
    ns_param .adp "text/html; charset=iso-8859-1"

ns_section "ns/encodings"
    ns_param adp "iso8859-1"

ns_section "ns/threads"
    ns_param stacksize [expr 128 * 1024]

ns_section "ns/servers"
    ns_param server1 "server1"

ns_section "ns/server/server1"
    ns_param directoryfile "index.htm,index.html,index.adp"
    ns_param pageroot $pageRoot
    ns_param maxthreads 20
    ns_param minthreads 5
    ns_param maxconnections 20
    ns_param urlcharset "utf-8"
    ns_param outputcharset "utf-8"
    ns_param inputcharset "utf-8"
    ns_param threadtimeout 60

ns_section "ns/server/server1/adp"
    ns_param map "/*.adp"

ns_section "ns/server/server1/modules"
    ns_param nssock nssock.so
    ns_param nslog nslog.so
    ns_param nscp nscp.so
    ns_param nsperl2 nsperl2.so

ns_section "ns/server/server1/module/nsperl2"
    ns_param init_script $nsperl2TestHome/test_startup.pl
    ns_param init_sub "Ns::Test::server_init"
    ns_param server "server1"

ns_section "ns/server/server1/module/nssock"
    ns_param hostname 127.0.0.1
    ns_param address 127.0.0.1
    ns_param port 8787

ns_section "ns/server/server1/module/nslog"
    ns_param rolllog true
    ns_param rollonsignal true
    ns_param rollhour 0
    ns_param maxbackup 2

ns_section "ns/server/server1/module/nscp"
    ns_param address "127.0.0.1"
    ns_param port 8786
    ns_param cpcmdlogging "false"

ns_section "ns/server/server1/module/nscp/users"
    ns_param user ":"

