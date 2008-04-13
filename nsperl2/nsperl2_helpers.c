#include "../nsperl2.h"


/* these global pointer-as-IV things are dangerous. figure out a better way... */

/* get the current tcl interp for the perl ithread - always only one ithread per tcl interpreter */
Tcl_Interp *__nsperl2_get_tcl_interp()
{
    SV *tcl_interp_sv = get_sv ("Ns::__tcl_interpPtr", TRUE | GV_ADDMULTI);
    
    if (!sv_derived_from(tcl_interp_sv, "Ns::nsperl2_tcl_interp"))
        croak("Ns::__tcl_interpPtr is not of type Ns::nsperl2_tcl_interp");

    IV tmp = SvIV((SV*)SvRV(tcl_interp_sv));

    return INT2PTR(Tcl_Interp *, tmp);
}

/* get the current itPtr for the tcl interpreter as per tclinit.c - is this public?? */

NsInterp *__nsperl2_get_itPtr(void)
{
    Tcl_Interp *interp = __nsperl2_get_tcl_interp (); /* defined in nsperl2.h */
    return interp ? __nsperl2_get_itPtr_from_interp (interp) : NULL;
}


SV *tcl_obj_to_sv(Tcl_Interp *interp, Tcl_Obj *obj, int expand_lists)
{
    int argc;
    int res;

    const char *type;

    if (!obj->typePtr) {
        if (!expand_lists)
           return tcl_strobj_to_sv(obj);
        
        res = Tcl_ListObjLength(interp, obj, &argc);
        if(res != TCL_OK || argc < 2) {
            /* if it's a one element list, let's leave it as a string */
            obj->typePtr = NULL;
            return tcl_strobj_to_sv(obj);
        }

        return tcl_listobj_to_sv(interp, obj);
    }

    type = obj->typePtr->name;

    if(STREQ(type, "list") && expand_lists)
        return tcl_listobj_to_sv(interp, obj);

    if(STREQ(type, "boolean"))
        return tcl_boolobj_to_sv(interp, obj);

    if(STREQ(type, "double"))
        return tcl_doubleobj_to_sv(interp, obj);

    if(STREQ(type, "int"))
        return tcl_intobj_to_sv(interp, obj);

    /* no special handling yet for builtin types index or bytecode */
    return tcl_strobj_to_sv(obj);
}

SV *tcl_listobj_to_sv(Tcl_Interp *interp, Tcl_Obj *listObj)
{
    int resargc;
    Tcl_Obj **resobjv;
    AV *av;

    if (Tcl_ListObjGetElements(interp, listObj, &resargc, &resobjv) != TCL_OK)
       return tcl_strobj_to_sv(listObj);

    av = newAV();
    while(resargc--)
       av_push(av, tcl_obj_to_sv(interp, *resobjv++, 1));

    return newRV((SV *)av);
}

SV *tcl_strobj_to_sv(Tcl_Obj *strObj)
{
    char *str;
    int str_len;

    str = Tcl_GetStringFromObj(strObj, &str_len);
    if( !str )
        return &PL_sv_undef;

    /* if there is both a leading and trailing brace {}, strip them */
    if (str[0] == '{' && str[str_len - 1] == '}') {
        str_len -= 2;
        str++;
    }

    return newSVpv(str, str_len);
}

SV *tcl_boolobj_to_sv(Tcl_Interp *interp, Tcl_Obj *boolObj)
{
    int boolVal;
    if( Tcl_GetBooleanFromObj(interp, boolObj, &boolVal) != TCL_OK )
        return &PL_sv_undef; /* should die with tcl error */

    return newSViv((IV) boolVal);
}

SV *tcl_doubleobj_to_sv(Tcl_Interp *interp, Tcl_Obj *doubleObj)
{
    double dbl;
    if( Tcl_GetDoubleFromObj(interp, doubleObj, &dbl) != TCL_OK )
        return &PL_sv_undef; /* should die with tcl error */

    return newSVnv(dbl);
}

SV *tcl_intobj_to_sv(Tcl_Interp *interp, Tcl_Obj *intObj)
{
    int intVal;
    if( Tcl_GetIntFromObj(interp, intObj, &intVal) != TCL_OK )
        return &PL_sv_undef; /* should die with tcl error */

    return newSViv((IV) intVal);
}

void resultObj_to_perl_stack(Tcl_Interp *interp, Tcl_Obj *resultObj)
{
        int resargc;
        Tcl_Obj **resobjv;

        dSP;

        if (!GIMME) {
           /* in perl scalar context, just give the full string result if it is a list */
           EXTEND(SP, 1);
           PUSHs(sv_2mortal(tcl_obj_to_sv(interp, resultObj, 0))); /* 0 - treat lists as strings */

        } else {
           /* perl list context */
           if (!resultObj->typePtr && Tcl_ConvertToType(interp, resultObj, Tcl_GetObjType("list")) != TCL_OK) {
             Ns_Log(Notice, "Unable to convert to type list");
             EXTEND(SP, 1);
             PUSHs(sv_2mortal(tcl_strobj_to_sv( resultObj ))); /* push string value of object */

           } else {
             /* was either an object to begin with, or has been successfully converted to a list object */

             if(STREQ(resultObj->typePtr->name, "list")) {
                 Tcl_ListObjGetElements(interp, resultObj, &resargc, &resobjv); /* first list level becomes perl result list */
                 EXTEND(SP, resargc);
                 while(resargc--)
                    PUSHs(sv_2mortal(tcl_obj_to_sv(interp, *resobjv++, 1))); /* 1 - expand embedded lists to array refs */

             } else {
                 /* a non-list object */
                 EXTEND(SP, 1);             
                 PUSHs(sv_2mortal(tcl_obj_to_sv(interp, resultObj, 0)));
              } 
           }
        }

        PUTBACK;
}

Tcl_Obj *sv_to_tcl_obj (SV *theSV)
{

  /* dereference - TODO: what about a ref to a ref? */
  if (SvROK(theSV) && SvTYPE(theSV) == SVt_RV)
    theSV = SvRV(theSV);

  switch(SvTYPE(theSV)) {
    case SVt_IV :
        return iv_to_tcl_obj (theSV);

    case SVt_NV :
        return nv_to_tcl_obj (theSV);

    case SVt_NULL :
    case SVt_BIND :
    case SVt_PV :
    case SVt_PVIV : /* can this be converted straight as an IV? */
    case SVt_PVNV : /* can this be converted straight as an NV? */
        return sv_to_tcl_strobj (theSV);

    case SVt_PVAV :
        return av_to_tcl_obj (theSV);

    case SVt_PVHV :
        return hv_to_tcl_obj (theSV);

    case SVt_PVCV :
    case SVt_PVFM :
        Ns_Log (Notice,"Code refs not yet supported in return values");
	return NULL;

    case SVt_PVGV :
    case SVt_PVIO :
        Ns_Log (Notice,"Globs and IO handles not yet supported in return values");
	return NULL;

    case SVt_PVMG :
        Ns_Log (Notice,"Blessed or magical scalars not yet supported in return values");
	return NULL;

    case SVt_PVLV :
        Ns_Log (Notice,"Not quite sure how an lvalue got here...");
	return NULL;
    
    case SVt_RV : 
      Ns_Log (Notice, "Not geared yet for a reference to a reference, which is what we seem to have here");
      return NULL;

    case SVt_LAST :
        Ns_Log (Notice,"I thought SVt_LAST was only a placeholder??");
	return NULL;
  }

  Ns_Log (Notice,"No understood type returned by SvTYPE");

  return NULL;
}

Tcl_Obj *iv_to_tcl_obj (SV *theSV)
{
    return Tcl_NewIntObj (SvIV (theSV));
}

Tcl_Obj *nv_to_tcl_obj (SV *theSV)
{
    return Tcl_NewDoubleObj (SvNV (theSV));
}

Tcl_Obj *av_to_tcl_obj (SV *theSV)
{
    Tcl_Obj *res;
    SV *el;
    Tcl_Interp *interp = __nsperl2_get_tcl_interp ();
    int len;

    res = Tcl_NewListObj (0, NULL);
    len = av_len((AV*)theSV);
    while(len-- && (el = av_shift ((AV*)theSV)))
      Tcl_ListObjAppendElement (interp, res, sv_to_tcl_obj (el));

    return res;
}

/* should offer choice of list of lists instead of flat {key val key val} list */
Tcl_Obj *hv_to_tcl_obj (SV *theSV)
{
    Tcl_Obj *res;
    SV *val;
    char *key;
    I32 len;
    Tcl_Interp *interp = __nsperl2_get_tcl_interp ();

    res = Tcl_NewListObj (0, NULL);

    while ((val = hv_iternextsv((HV*)theSV, &key, &len))) {
        Tcl_ListObjAppendElement (interp, res, Tcl_NewStringObj (key, (int)len));
        Tcl_ListObjAppendElement (interp, res, sv_to_tcl_obj (val));
    }

    return res;
}

Tcl_Obj *sv_to_tcl_strobj (SV *theSV)
{
    char *theStr;
    STRLEN len;
    Tcl_Obj *resObj;

    theStr = SvPV(theSV, len);

    resObj = Tcl_NewStringObj (theStr, (int)len);

    return resObj;
}

nsperl2_Ns_Set *nsperl2_Ns_Set_new(char *name, Ns_Set *set, char *setId, int persist_perl, int persist_tcl)
{
    nsperl2_Ns_Set *ret;
    
    ret = safemalloc(sizeof(nsperl2_Ns_Set));
    if(set)
         ret->set = set;
    else
         ret->set = Ns_SetCreate(name);

    ret->persist_perl = persist_perl;
    ret->persist_tcl = persist_tcl;
    ret->setId = setId;

    return ret;
}

void set_nsperl2_globals (PerlInterpreter *perl_interp, Tcl_Interp *interp, Ns_Conn *conn )
{
    dTHX;
    PERL_SET_CONTEXT (perl_interp);

    SV *connVarPtr = get_sv ("Ns::Conn::__current_conn", TRUE | GV_ADDMULTI);
    SV *tcl_interpPtr = get_sv ("Ns::__tcl_interpPtr", TRUE | GV_ADDMULTI);

    sv_setref_pv(tcl_interpPtr, "Ns::nsperl2_tcl_interp", (void*)interp);

    if (!conn) {

        NsInterp *itPtr = __nsperl2_get_itPtr_from_interp(interp);
        if ((NsTclGetConn (itPtr, &conn)) != TCL_OK)
            conn = NULL; /* just in case it leaves it non-null */
    }

    if(conn) {

        /* store conn as an Ns::Conn in perl interp global */
        
        HV *hashRef = newHV ();
        SV *hashObj = newRV_noinc ( (SV *) hashRef);
        SV *conn_impl_sv = newSV (0);
        sv_setref_pv(conn_impl_sv, "Ns::Conn_impl", (void*)conn);
            
        hv_store (hashRef, "__ns_conn_address", 17, conn_impl_sv, 0);
        sv_bless (hashObj, gv_stashpv ("Ns::Conn", TRUE));
        
        sv_setsv (connVarPtr, hashObj);

        Ns_Log (Notice, "created Ns::Conn perl object with refcnts: obj: %d ptr: %d", (uint)SvREFCNT (hashObj), (uint)SvREFCNT (SvRV (connVarPtr)));

    } else {

        /* we're not in a context where there is a conn (eg. scheduled proc) so undef it */
        if (SvROK(connVarPtr))
            SvREFCNT_dec(SvRV(connVarPtr));
        sv_setsv (connVarPtr, &PL_sv_undef);
    }
}


int nsperl2_call_perl (Tcl_Interp *interp, Ns_Conn *conn, char *sub, SV *sub_sv, int objc, Tcl_Obj **objv, SV *perl_arg, int list_context)
{
    int flags = G_EVAL, count;
    Tcl_Obj *tclResList;
    STRLEN n_a;
    int i;
    perl_context *context;

    if(!interp && conn)
        interp = Ns_GetConnInterp (conn);

    if (!interp)
        croak ("No interpreter available for nsperl2_call_perl");

    context = nsperl2_get_assoc_perl_context (interp);

    if(list_context)
        flags |= G_ARRAY;

    dTHX;
    PERL_SET_CONTEXT (context->perl_interp);
    dSP;

    set_nsperl2_globals (context->perl_interp, interp, conn);
                
        ENTER;
    SAVETMPS;

    PUSHMARK (SP);

    if (perl_arg) { /* there is a perl arg - should we expand an AV?? */
        EXTEND (SP, 1);
        SV *tmpsv = newSVsv (perl_arg); /* ERROR: can this be fixed with not using perl malloc, or do we need to dclone each time?? */
        PUSHs (tmpsv);
        
    } else if(objc) { /* there are tcl arguments for the perl call */
        EXTEND (SP, objc);
    
        for ( i=0 ; i < objc ; i++ )
            PUSHs(sv_2mortal(tcl_obj_to_sv(interp, objv[i], 1)));
    } else
        flags |= G_NOARGS;

    PUTBACK;

        /* call_sv takes an sv instead of a pv - that would allow us to eg. call closures,
       but we need a way to save codrefs to tcl */
    /* also if we saved blessed perl refs to tcl we could use call_method to call methods on perl objects */
    /* we will need to make our own tcl object type - but allowing it to survive a round trip from a string
       version would be tough */

    if (sub_sv)
        count = call_sv (sub_sv, flags);
    else
        count = call_pv(sub, flags);

    int ret = TCL_OK;

    /* check $@ */
    if(SvTRUE(ERRSV)) {
        Ns_Log (Error, "perl eval error: %s\n", SvPV(ERRSV,n_a));
        POPs; /* exception leaves undef on top of stack according to perlcall */
        ret = TCL_ERROR;
    }

    SPAGAIN;

    /* this will give args in forward order instead of POPs */
    tclResList = Tcl_NewListObj (0, NULL);

    Tcl_Obj *res_object;
    if(!list_context) {
        if (count != 1) {
            Ns_Log(Error,"got more than one result in scalar context!!");
            return TCL_ERROR;
        }
	res_object = sv_to_tcl_obj (POPs);
	if (!res_object) {
	  SP -= count;
	  PUTBACK;
	  FREETMPS;
	  LEAVE;
	  return TCL_ERROR;
	}
        Tcl_ListObjAppendElement (interp, tclResList, res_object);

    } else {
        for (i=0;i < count; i++) {
            int offset = count - i - 1;
            SV *sv = sv_mortalcopy (*(SP - offset));
	    res_object = sv_to_tcl_obj (sv);
	    if(!res_object) {
	      SP -= count;
	      PUTBACK;
	      FREETMPS;
	      LEAVE;
	      return TCL_ERROR;
	    }
            Tcl_ListObjAppendElement (interp, tclResList, res_object);
        }

        /* pop all off stack */
        SP -= count;
    }

    Tcl_SetObjResult (interp, tclResList);

    PUTBACK;
    FREETMPS;
    LEAVE;

    return ret;
}
