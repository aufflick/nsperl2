#include "../nsperl2.h"
#include "ppport.h"

#define CONN Ns_Conn *conn = self_conn(self); if (!conn) XSRETURN_UNDEF;

Ns_Conn *self_conn(HV *self)
{
    SV **conn_sv = hv_fetch(self, "__ns_conn_address", 17, NULL);
    STRLEN n_a;

    if(!conn_sv)
        croak("Ns::Conn object has no __ns_conn_address");

    if (!sv_derived_from(*conn_sv, "Ns::Conn_impl"))
       croak("__ns_conn_address is not of type Ns::Conn_impl");

    IV tmp = SvIV((SV*)SvRV(*conn_sv));

    return INT2PTR(Ns_Conn *, tmp);
}


/* add prefix */

MODULE = Ns::Conn		PACKAGE = Ns::Conn		PREFIX = Ns_Conn

char *Ns_ConnAuthPasswd(HV * self)
     ALIAS:
        authpassword = 1
     C_ARGS:
        conn
     INIT:	
		CONN;

char *Ns_ConnAuthUser(HV * self)
     ALIAS:
        authuser = 1
     C_ARGS:
        conn
     INIT:	
		CONN;

int Ns_ConnClose(HV * self)
     ALIAS:
        close = 1
     C_ARGS:
        conn
     INIT:	
		CONN;

int Ns_ConnContentLength(HV * self)
    ALIAS:
        contentlength = 1
    C_ARGS:
        conn
    INIT:
		CONN;

char *Ns_ConnDriverName(HV * self)
     ALIAS:
        driver = 1
     C_ARGS:
        conn
     INIT:
		CONN;

# THis is special because the docs say to not allow the setP to be
# altered or deallocated. So, we copy it.
#
# Also note the name confusion between the tcl and C API in the following two xsubs */

nsperl2_Ns_Set *Ns_ConnGetQuery(HV * self)
    ALIAS:
        form = 1
    PREINIT:
        Ns_Set * setP;
    CODE:	
		CONN;
	    setP = Ns_ConnGetQuery(conn);

	    if(setP)
            RETVAL = nsperl2_Ns_Set_new(NULL, Ns_SetCopy( setP ), NULL, 1, 1);
        else
	        RETVAL = nsperl2_Ns_Set_new("", NULL, NULL, 0, 0);
    OUTPUT:
        RETVAL

char * query(HV * self)
    INIT:
        CONN;
    CODE:
        RETVAL = conn->request->query;
    OUTPUT:
        RETVAL

nsperl2_Ns_Set * headers(HV * self)
    INIT:
        CONN;
    CODE:
        RETVAL = nsperl2_Ns_Set_new(NULL, Ns_SetCopy( conn->headers ), NULL, 1, 1);
    OUTPUT:
        RETVAL

char *Ns_ConnHost(HV * self)
    ALIAS:
        host = 1
    C_ARGS:
        conn
    INIT:
        CONN;

char *Ns_ConnLocation(HV * self)
     ALIAS:
        location = 1
     C_ARGS:
        conn
     INIT:
        CONN;

char *method(HV * self)
     INIT:
        CONN;
     CODE:
        RETVAL = conn->request->method;
     OUTPUT:
        RETVAL

# output headers ns_set is read/write, so no need to copy
# but do need to flag as persistant, currently done in perl wrapper
# rather than alias

nsperl2_Ns_Set * Ns_ConnOutputHeaders(HV * self)
    CODE:
        CONN;
        RETVAL = nsperl2_Ns_Set_new(NULL, Ns_ConnOutputHeaders(conn), NULL, 1, 1);
    OUTPUT:
        RETVAL

char *Ns_ConnPeer(HV * self)
    ALIAS:
        peeraddr = 1
    C_ARGS:
        conn
    INIT:
        CONN;

int Ns_ConnPort(HV * self)
    ALIAS:
        port = 1
    C_ARGS:
        conn
    INIT:
        CONN;

char *protocol(HV * self)
     INIT:
        CONN;
     CODE:
        RETVAL = conn->request->protocol;
     OUTPUT:
        RETVAL

char *request(HV * self)
     INIT:
        CONN;
     CODE:
        RETVAL = conn->request->line;
     OUTPUT:
        RETVAL

char *url(HV * self)
     INIT:
        CONN;
     CODE:
        RETVAL = conn->request->url;
     OUTPUT:
        RETVAL

int urlc(HV * self)
     INIT:
        CONN;
     CODE:
        RETVAL = conn->request->urlc;
     OUTPUT:
        RETVAL

# urlv is a list - TODO: implement

double version(HV * self)
     INIT:
        CONN;
     CODE:
        RETVAL = conn->request->version;
     OUTPUT:
        RETVAL

void return(HV *self, int status, char *type, SV *content)
      INIT:
        CONN;
      CODE:
        STRLEN len;
        char *content_str;
        content_str = SvPV(content, len);
        if(Ns_ConnReturnData(conn, status, content_str, (int)len, type) != TCL_OK)
             croak("Ns_ConnReturnCharData failed"); /* TODO: need a utility func to croak with tcl error string if available */

void Ns_ConnReturnRedirect(HV *self, char *location)
     INIT:
        CONN;
     ALIAS:
        returnredirect = 1
     C_ARGS:
        conn, location

void returnerror(HV *self, int status, char *msg)
     INIT:
        CONN;
     CODE:
        Ns_ConnReturnAdminNotice(conn, status, "Request Error",  msg);

void Ns_ConnReturnNotFound(HV *self)
     INIT:
        CONN;
     ALIAS:
        returnnotfound = 1
     C_ARGS:
        conn

void Ns_ConnReturnBadRequest(HV *self, char *msg)
     INIT:
        CONN;
     ALIAS:
        returnbadrequest = 1
     C_ARGS:
        conn, msg

void Ns_ConnReturnAdminNotice(HV *self, int status, char *msg, char *longmsg = NULL)
     INIT:
        CONN;
     ALIAS:
        returnadminnotice = 1
     C_ARGS:
        conn, status, msg, longmsg

void Ns_ConnReturnNotice(HV *self, int status, char *msg, char *longmsg = NULL)
     INIT:
        CONN;
     ALIAS:
        returnnotice = 1
     C_ARGS:
        conn, status, msg, longmsg

void Ns_ConnReturnForbidden(HV *self)
     INIT:
        CONN;
     ALIAS:
        returnforbidden = 1
        returnunauthorized = 2
     C_ARGS:
        conn

void Ns_ConnReturnFile(HV *self, int status, char *type, char *filename)
     INIT:
        CONN;
     ALIAS:
        returnfile = 1
     C_ARGS:
        conn, status, type, filename


