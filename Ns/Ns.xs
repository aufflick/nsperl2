#include "../nsperl2.h"
#include "ppport.h"

/* TODO: there are *certainly* memory leaks and refcount issues here - perl and tcl */

int nsperl2PerlRequest (void *context, Ns_Conn *conn);

int nsperl2PerlRequest (void *context, Ns_Conn *conn)
{
    nsperl2PerlRequestContext *args = (nsperl2PerlRequestContext*)context;
    Tcl_Interp *interp = Ns_GetConnInterp (conn);
    int ret;
    SV *pargs = NULL;
    perl_context *p = nsperl2_get_assoc_perl_context(interp);
    SV *perl_sub;

    assert(args);

    if(!args->perl_args_frozen && args->tcl_args) {
        pargs = tcl_obj_to_sv (interp, args->tcl_args, 1);
    } else if(args->perl_args_frozen) {
      PERL_SET_CONTEXT(p->perl_interp);
      dSP;
      PUSHMARK(SP);
      XPUSHs(args->perl_args_frozen);
      PUTBACK;
      int count = call_pv("Storable::thaw", G_SCALAR);
      SPAGAIN;
      if (count != 1)
         croak("unexptected return from storable");
      pargs =  POPs;
    }

    if (args->perl_sub)
        perl_sub = newSVpv(args->perl_sub, 0);
    else if (args->dispatch_key) {
        /* lookup coderef out of dispatch table */
        HV *dispatch = get_hv("Ns::_dispatch", 0);
        assert(dispatch);
        SV **coderef = hv_fetch(dispatch, args->dispatch_key, strlen(args->dispatch_key), NULL);
        assert(coderef);
        perl_sub = *coderef;
    }
    assert(perl_sub);

    if(args->perlish) {
        AV *av = newAV();
        av_push(av, perl_sub);
        av_push(av, pargs);
        pargs = newRV_noinc((SV*)av);
        perl_sub = newSVpv("Ns::perlish_request", 0);
    }
    
    ret = nsperl2_call_perl (interp, NULL, NULL, perl_sub, 0, NULL, pargs, 0); /* scalar context */

    /* do something with the returned value - perhaps a flag to call_perl to say we just want truth returned? */

    return ret;
}


MODULE = Ns		PACKAGE = Ns		

void tcl_eval(const char * code)
    PPCODE:
        Tcl_Interp *interp = __nsperl2_get_tcl_interp();
        Tcl_Obj *resultObj;

        if (!interp)
           XSRETURN_UNDEF;

        /* how to handle perl->tcl utf8? Tcl_ExternalToUtf is involved on the tcl end */
        if (!Tcl_Eval(interp, code) == TCL_OK)
           XSRETURN_UNDEF; /* TODO: should actually die with the tcl error */
        resultObj = Tcl_GetObjResult(interp);

        PUTBACK;
        resultObj_to_perl_stack(interp, resultObj);
        SPAGAIN;
        
        Tcl_ResetResult(interp);

# the next two subs are used by the perl wrapper tcl_prepare
# which returns a perl coderef

# sub to prepare a piece of code into a tcl object
# will be lazily compiled first time it is executed
nsperl2_TclCodeObj *_tcl_prepare(const char * code)
     CODE:
        Tcl_Interp *interp = __nsperl2_get_tcl_interp();

        RETVAL = Tcl_NewStringObj(code, -1); /* -1 == all chars up to first null */
     OUTPUT:
        RETVAL

# sub to execute a compiled tcl object
void _tcl_exec_obj(nsperl2_TclCodeObj *obj, int global)
     PPCODE:
        Tcl_Interp *interp = __nsperl2_get_tcl_interp();
        Tcl_Obj *resultObj;
        int flags = 0;
        if(global)
            flags = TCL_EVAL_GLOBAL;

        if( Tcl_EvalObjEx(interp, obj, flags) != TCL_OK )
            XSRETURN_UNDEF; /* TODO: should croak tcl error */

        resultObj = Tcl_GetObjResult(interp);

        PUTBACK;
        resultObj_to_perl_stack(interp, resultObj);
        SPAGAIN;
        
        Tcl_ResetResult(interp);

# sub to register a perl sub against an url
void _register_url(HV *args)
     CODE:
        NsInterp *itPtr = __nsperl2_get_itPtr();
        char *method, *url, *server, *perl_sub = NULL, *dispatch_key = NULL;
        SV **method_sv, **url_sv, **noinherit_sv, **perl_sub_sv, **dispatch_key_sv, **args_sv, **perlish_sv;
        int flags = 0;
        STRLEN n_a, perl_sub_len, dispatch_key_len;
        nsperl2PerlRequestContext *context;

        noinherit_sv = hv_fetch(args, "noinherit", 9, NULL);
        if (noinherit_sv && SvTRUE(*noinherit_sv))
           flags |= NS_OP_NOINHERIT;
        
        method_sv = hv_fetch(args, "http_method", 11, NULL);
        if (!method_sv)
           croak("Ns::register_url requires http_method argument");
        method = SvPV(*method_sv, n_a);

        url_sv = hv_fetch(args, "url", 3, NULL);
        if (!url_sv)
           croak("Ns::register_url requires url argument");
        url = SvPV(*url_sv, n_a);

        perl_sub_sv = hv_fetch(args, "perl_sub", 8, NULL);
        dispatch_key_sv = hv_fetch(args, "dispatch_key", 12, NULL);
        if (
            (!perl_sub_sv || SvTYPE(*perl_sub_sv) != SVt_PV) &&
            (!dispatch_key_sv || SvTYPE(*dispatch_key_sv) != SVt_PV)
           )
           croak("Ns::register_url requires sub argument");

        if (perl_sub_sv)
           perl_sub = SvPV(*perl_sub_sv, perl_sub_len);
        else
           dispatch_key = SvPV(*dispatch_key_sv, dispatch_key_len);

        if (!itPtr || (NsTclGetServer(itPtr, &server) != TCL_OK))
           croak("Ns::register_url Unable to retrieve server name");

        Newx(context, 1, nsperl2PerlRequestContext);
        context->tcl_args = NULL;
        if(perl_sub) {
             context->perl_sub = savepv(perl_sub);
             context->dispatch_key = NULL;
        } else {
             context->dispatch_key = savepv(dispatch_key);
             context->perl_sub = NULL;
        }
        
        perlish_sv = hv_fetch(args, "perlish", 7, NULL);
        context->perlish = (perlish_sv && SvTRUE(*perlish_sv)) ? 1 : 0;

        Ns_Log(Notice, "Registering perl request: server=%s method=%s url=%s perl_sub=%s dispatch_key=%s perlish=%d", server, method, url, context->perl_sub, context->dispatch_key, context->perlish);

        args_sv = hv_fetch(args, "args", 4, NULL);
        if(args_sv && SvOK(*args_sv)) {
            /* unfortunately since proc is registered in a single table, the context pointer will
               not be specific to the then current perl context.
               one solution would be to recursively make the data structure passed in
               threads::shared, but that could lead to non-scalable locking.
               
               instead we will serialise/unserialise */
            PUSHMARK(SP);
            XPUSHs(*args_sv);
            PUTBACK;
            /* could call a Storable internal sub and avoid any perl at all, but lets be safe */
            int count = call_pv("Storable::freeze", G_SCALAR);
            SPAGAIN;
            if (count != 1)
               croak ("unexpected return from storable");
            SV *f = POPs;
            context->perl_args_frozen = SvREFCNT_inc(f);
        } else
            context->perl_args_frozen = NULL;
        
        Ns_RegisterRequest(server, method, url, nsperl2PerlRequest, NULL, context, flags); /* TODO: add free proc which will free */


