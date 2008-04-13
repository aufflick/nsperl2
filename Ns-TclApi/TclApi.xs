#include "../nsperl2.h"
#include "ppport.h"

typedef struct {
    Tcl_Obj *tcl_proc_obj;
    int global;
} nsperl2_TclApi;

void _call(nsperl2_TclApi *self, int items, I32 ax, Tcl_Obj *method_obj) { /* is there a more kosher way than passing in ax? */
        Tcl_Interp *interp;
        Tcl_Obj *resultObj;
        Tcl_Obj **objv;
        int objc, objc_copy, i, j;
        int flags;
     
        dSP;
     
        objc_copy = objc = items; /* nb: items is count of all @_, so is method args + 1 already */

        if(method_obj)
            objc++; /* need to push AUTOLOADed method name into argv also */

        if (!( objv = safemalloc(sizeof(Tcl_Obj *) * objc) ))
           croak("Unable to allocate memory in Ns::TclApi::CALL");

        i = 0;

        objv[i] = self->tcl_proc_obj;
        objc_copy--;
        i++;

        if(method_obj) {
            /* came from AUTOLOAD */
            objv[i] = method_obj;
            i++;
        }
        for (j=1 ; j <= objc_copy ; j++)
            objv[i++] = sv_to_tcl_strobj(ST(j));

        for (j=1 ; j <= objc_copy ; j++)
            POPs;

        flags = 0;
        if(self->global)
            flags = TCL_EVAL_GLOBAL;

        interp = __nsperl2_get_tcl_interp();

        if (Tcl_EvalObjv(interp, objc, objv, flags) != TCL_OK)
           croak("Unable to eval. tcl command: %s", Tcl_GetStringFromObj(objv[0], NULL)); /* add tcl error message */

        resultObj = Tcl_GetObjResult(interp);

        PUTBACK;
        resultObj_to_perl_stack(interp, resultObj);
        
        Tcl_ResetResult(interp);
}



MODULE = Ns::TclApi		PACKAGE = Ns::TclApi

# could cache these in an Ns_Set, but I don't think the command string object
# gets any pre-compiled bytecode, so probablly not worth the effort
nsperl2_TclApi *make(char *class, char *tcl_proc_name, int global)
     CODE:
       int proc_strlen = strlen(tcl_proc_name);
       if(!proc_strlen)
           croak("tcl_proc_name required");

       RETVAL = (nsperl2_TclApi *)safemalloc(sizeof(nsperl2_TclApi));
       RETVAL->global = global;
       RETVAL->tcl_proc_obj = Tcl_NewStringObj (tcl_proc_name, proc_strlen);
       Tcl_IncrRefCount(RETVAL->tcl_proc_obj);
     OUTPUT:
       RETVAL

void DESTROY(nsperl2_TclApi *self)
     CODE:
        Tcl_DecrRefCount(self->tcl_proc_obj);
        safefree(self);

void CALL(nsperl2_TclApi *self, ...)
     PPCODE:
        PUTBACK;
        _call(self, items, ax, NULL);
        SPAGAIN;

void AUTOLOAD(nsperl2_TclApi *self, ...)
     PPCODE:
        char *method = SvPVX(cv); /* AUTOLOAD method name is stashed in unused cv fields as per gv.c line 713 */
        int method_len = SvCUR(cv);
        Tcl_Obj *method_obj = Tcl_NewStringObj(method, method_len);

        PUTBACK;
        _call(self, items, ax, method_obj);
        SPAGAIN;
        /* method_obj already has refcount 0 */
