

/* the following copied from nsd source files - ideally find a way to not have to do
   this, even if it means #include */

#define SET_DYNAMIC 		'd'
#define SET_STATIC    		't'
#define SET_SHARED_DYNAMIC	's'
#define SET_SHARED_STATIC  	'p'

#define IS_DYNAMIC(id)    \
	(*(id) == SET_DYNAMIC || *(id) == SET_SHARED_DYNAMIC)
#define IS_SHARED(id)     \
	(*(id) == SET_SHARED_DYNAMIC || *(id) == SET_SHARED_STATIC)


static int LookupSet(NsInterp *itPtr, char *id, int delete, Ns_Set **setPtr); /* from tclset.c */
static int
LookupSet(NsInterp *itPtr, char *id, int delete, Ns_Set **setPtr)
{
    Tcl_HashTable *tablePtr;
    Tcl_HashEntry *hPtr;
    Ns_Set        *set;

    /*
     * If it's a persistent set, use the shared table, otherwise
     * use the private table.
     */
    
    set = NULL;
    if (IS_SHARED(id)) {
    	tablePtr = &itPtr->servPtr->sets.table;
        Ns_MutexLock(&itPtr->servPtr->sets.lock);
    } else {
	tablePtr = &itPtr->sets;
    }
    hPtr = Tcl_FindHashEntry(tablePtr, id);
    if (hPtr != NULL) {
        set = (Ns_Set *) Tcl_GetHashValue(hPtr);
        if (delete) {
            Tcl_DeleteHashEntry(hPtr);
        }
    }
    if (IS_SHARED(id)) {
        Ns_MutexUnlock(&itPtr->servPtr->sets.lock);
    }
    if (set == NULL) {
	Tcl_AppendResult(itPtr->interp, "no such set: ", id, NULL);
	return TCL_ERROR;
    }
    *setPtr = set;
    return TCL_OK;
}


static int EnterSet(NsInterp *itPtr, Ns_Set *set, int flags); /* from tclset.c */
static int
EnterSet(NsInterp *itPtr, Ns_Set *set, int flags)
{
    Tcl_HashTable  *tablePtr;
    Tcl_HashEntry  *hPtr;
    int             new, next;
    unsigned char   type;
    char	    buf[20];

    if (flags & NS_TCL_SET_SHARED) {
	/*
	 * Lock the global mutex and use the shared sets.
	 */
	
	if (flags & NS_TCL_SET_DYNAMIC) {
       Ns_Log(Notice, "DYNAMIC");
	    type = SET_SHARED_DYNAMIC;
	} else {
        Ns_Log(Notice, "STATIC");
	    type = SET_SHARED_STATIC;
	}
	tablePtr = &itPtr->servPtr->sets.table;
        Ns_MutexLock(&itPtr->servPtr->sets.lock);
    } else {
	tablePtr = &itPtr->sets;
	if (flags & NS_TCL_SET_DYNAMIC) {
	    type = SET_DYNAMIC;
	} else {
            type = SET_STATIC;
	}
    }

    /*
     * Allocate a new set IDs until we find an unused one.
     */
    
    next = tablePtr->numEntries;
    do {
        sprintf(buf, "%c%u", type, next);
	++next;
        hPtr = Tcl_CreateHashEntry(tablePtr, buf, &new);
    } while (!new);
    Tcl_SetHashValue(hPtr, set);
    Tcl_AppendElement(itPtr->interp, buf);

    /*
     * Unlock the global mutex (locked above) if it's a persistent set.
     */
    if (flags & NS_TCL_SET_SHARED) {
        Ns_MutexUnlock(&itPtr->servPtr->sets.lock);
    }
    return TCL_OK;
}
