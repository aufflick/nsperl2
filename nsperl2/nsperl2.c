#include "../nsperl2.h"

static const char *RCSID = "@(#) $Header: /cvsroot/aolserver/aolserver/nslog/nslog.c,v 1.16 2005/08/08 11:32:18 jgdavidson Exp $, compiled: " __DATE__ " " __TIME__;

int Ns_ModuleVersion = 1;

static Tcl_ObjCmdProc NsPerl2CallCmd;
static Ns_TclInterpInitProc NsPerl2InitInterp;

perl_master_context *nsperl2_master_context;

EXTERN_C void xs_init (pTHX);

EXTERN_C void boot_DynaLoader (pTHX_ CV* cv);

EXTERN_C void
xs_init(pTHX)
{
	char *file = __FILE__;
	dXSUB_SYS;

	/* DynaLoader is a special case */
	newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
}

/* MacOS X has no extern envion variable available to dynamic linked modules */
#ifdef __APPLE__
#include <crt_externs.h>
#define environ_h (_NSGetEnviron())
#else
extern char **environ;
#define environ_h (&environ)
#endif

int
NsPerl2_ModInit(char *server, char *module)
{
    extern perl_master_context *nsperl2_master_context;
    int perl_exitstatus;
    Ns_Log(Notice,"nsperl2: loading");

    if (!(nsperl2_master_context = ns_malloc (sizeof(perl_master_context))))
        return TCL_ERROR;

    /* determine initial perl script */
    nsperl2_master_context->param_path = Ns_ConfigGetPath(server, module, NULL);
    nsperl2_master_context->init_script = Ns_ConfigGetValue(nsperl2_master_context->param_path, "init_script");
    nsperl2_master_context->init_sub = Ns_ConfigGetValue(nsperl2_master_context->param_path, "init_sub");
    nsperl2_master_context->server = Ns_ConfigGetValue(nsperl2_master_context->param_path, "server");

    /* TODO: what to do if multiple servers? probably need a master context per server */

    Ns_Log (Notice, "nsperl2: init_script is %s", nsperl2_master_context->init_script);
    char *embedding[] = { "", nsperl2_master_context->init_script };
    PerlInterpreter *perl_interp;

    int perl_argc = 0;
    char **perl_argv = NULL;

    PERL_SYS_INIT3( &perl_argc, &perl_argv, environ_h );

    /* create perl interpreter */

    if((perl_interp = perl_alloc()) == NULL) {
        Ns_Log (Error, "Couldn't alloc perl interp");
        return TCL_ERROR;
    }

    perl_construct(perl_interp);
    PL_exit_flags |= PERL_EXIT_DESTRUCT_END; /* run END blocks at destruction */

    PERL_SET_CONTEXT (perl_interp);
    perl_exitstatus = perl_parse(perl_interp, xs_init, 2, embedding, NULL);

    /* TODO: check perl_exitstatus */

    nsperl2_master_context->perl_master_interp = perl_interp;

    /* call the init_sub - eg. where urls are registered etc. 
       you could do the same in a BEGIN block, but this is cleaner */

    dSP;
    PUSHMARK (SP);
    Tcl_Interp *tcl_interp;
    tcl_interp = Ns_TclAllocateInterp (server);
    set_nsperl2_globals (perl_interp, tcl_interp, NULL);
    call_pv (nsperl2_master_context->init_sub, G_NOARGS | G_VOID | G_DISCARD); /* not doing G_EVAL - if init_sub fails, we want to bail. */
    /* should I destroy that tcl interp?? */

    Ns_RegisterShutdown (nsperl2_free_master_context, NULL);
    
    Ns_TclInitInterps(server,NsPerl2InitInterp, NULL);

    return NS_OK;
}

void nsperl2_free_master_context (void *context)
{
    extern perl_master_context *nsperl2_master_context;
    assert (nsperl2_master_context);
    Ns_Log (Notice, "in nsperl2_free_master_context - about to free and destruct master perl context");
    PERL_SET_CONTEXT (nsperl2_master_context->perl_master_interp);
    perl_destruct (nsperl2_master_context->perl_master_interp);
    perl_free (nsperl2_master_context->perl_master_interp);
    PERL_SYS_TERM();
}

EXTERN Tcl_Namespace *	Tcl_CreateNamespace _ANSI_ARGS_((Tcl_Interp * interp, 
				CONST char * name, ClientData clientData, 
				Tcl_NamespaceDeleteProc * deleteProc));

static int
NsPerl2InitInterp(Tcl_Interp *interp, void *context)
{
    Tcl_Namespace *nsPtr;

    nsPtr = Tcl_CreateNamespace(interp, "perl", NULL, NULL);
    if(!nsPtr)
        return TCL_ERROR;
    Tcl_CreateObjCommand(interp,"perl::call",NsPerl2CallCmd, NULL, NULL);

    Tcl_PkgProvide(interp, "nsperl2", "0.1");
     
    return TCL_OK;
}

/* lazily maintain 1:1 mapping between tcl and perl interpreters */
perl_context *nsperl2_get_assoc_perl_context (Tcl_Interp *interp)
{
    extern perl_master_context *nsperl2_master_context;
    assert (nsperl2_master_context);
    perl_context *context = Tcl_GetAssocData (interp, "nsperl2:perl_context", NULL);
    PerlInterpreter *perl_interp;

    if(context)
        return context;

    Ns_Log (Notice, "cloning perl interpreter for tcl interp");

    PERL_SET_CONTEXT (nsperl2_master_context->perl_master_interp);

    if ((perl_interp = perl_clone (nsperl2_master_context->perl_master_interp, CLONEf_KEEP_PTR_TABLE)) == NULL) {
        Ns_Log (Error, "Couldn't clone perl interp");
        return NULL;
        }

    /* save the perl interp */
    context = ns_malloc (sizeof(perl_context));
    context->perl_interp = perl_interp;
    Tcl_SetAssocData(interp, "nsperl2:perl_context", nsperl2_delete_assoc_perl, context);

    return context;
}

void nsperl2_delete_assoc_perl( ClientData clientData, Tcl_Interp *interp)
{
    perl_context *context = (perl_context *) clientData;
    Ns_Log (Notice, "in nsperl2_delete_assoc_perl - about to free and destruct interp perl context");
    PERL_SET_CONTEXT (context->perl_interp);
    /* perl_destruct (context->perl_interp); - I don't think we want to run END blocks for each interp shutdown do we?? */
    perl_free (context->perl_interp);
    ns_free ((void*)context);
}

static int
NsPerl2CallCmd(ClientData ignore,Tcl_Interp *interp,int objc, Tcl_Obj *CONST objv[])
{
    int ret;
    char *sub;
    int subIdx = 1;
    int list_context = 1;
    int perl_objc;
    Tcl_Obj **perl_objv;

    Ns_Log(Notice,"NsPerl2Cmd called");

    /* check args */
    if(STREQ (Tcl_GetString (objv[subIdx]), "-scalar")) {
        subIdx++;
        list_context = 0;
    }

    sub = Tcl_GetString (objv[subIdx]);

    Ns_Log (Notice, "perl sub is: %s", sub);

    perl_objc = objc - subIdx - 1;
    if( perl_objc > 0 )
        perl_objv = objv + subIdx + 1;
    else {
        perl_objv = NULL;
        perl_objc = 0;
    }

    ret = nsperl2_call_perl (interp, NULL, sub, NULL, perl_objc, perl_objv, NULL, list_context);

    /* free objv args?? */

    return ret;
}
