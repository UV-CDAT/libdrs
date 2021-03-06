c**********************************************************************
c getcdim.F,v 2.4 1995/10/16 18:48:04 drach Exp
c getcdim.F,v
c Revision 2.4  1995/10/16  18:48:04  drach
c - Declare d_floor for DEC Alpha version
c
c Revision 2.3  1995/07/28  22:55:00  drach
c - Modified for IBM RS/6000 version
c
c Revision 2.2  1995/03/30  00:50:44  drach
c Added disclaimer
c
c Revision 2.1  1993/07/13  01:12:52  drach
c Merged Sun, Unicos, SGI, and HP versions.
c
c Revision 2.0  1992/03/07  00:08:14  drach
c Entered into RCS
c
c
c
c                     Data Retrieval and Storage System
c
c**********************************************************************
c
c			DISCLAIMER
c
c   This software was prepared as an account of work sponsored by an
c   agency of the United States Government. Neither the United
c   States Government nor the University of California nor any of
c   their employees, makes any warranty, express or implied, or
c   assumes any liability or responsibility for the accuracy,
c   completeness, or usefulness of any information, apparatus,
c   product, or process disclosed, or represents that its use would
c   not infringe privately owned rights. Reference herein to any
c   specific commercial products, process, or service by trade name,
c   trademark, manufacturer, or otherwise, does not necessarily
c   constitute or imply its endorsement, recommendation, or favoring
c   by the United States Government or the University of California.
c   The views and opinions of authors expressed herein do not
c   necessarily state or reflect those of the United States
c   Government or the University of California, and shall not be
c   used for advertising or product endorsement purposes.
c   
c**********************************************************************
c
c     Routine: 
c     -------
      integer function getcdim(ndim,source,name,title,units,dtype,
     $     reqlen,dvar,retlen)
      integer ndim,dtype,reqlen,retlen
      character*(*) source,name,title,units
c      dimension dvar(reqlen)
      dimension dvar(*)
c
c     Description:
c     -----------
c     Get dimension info for dimension ndim. 
c
c     Arguments:
c     ---------
c     ndim   =:  dimension number
c     source  := dimension source
c     name    := dimension name
c     title   := dimension title
c     units   := dimension units
c     dtype   := dimension type (integer)
c     reqlen =:  length of var in words
c     var     := dimension variable
c     retlen  := number of words returned in var
c     
c     
c     Function Returns:
c     ----------------
c       0: success
c     
c     Author: Bob Drach
c     ------
c
c     Date: 6/14/90
c     Modified: 7/3/91 to call getvdim with 0 requested len when reqlen=0
c     ----
c
c     Notes:
c     -----
c     (1) This routine supersedes getvdim and getdim.
c     It may be used in any context
c     including following a getslab call.
c
c     (2) If getcdim is called following a getslab call, it will return
c     any cycle dimensions specified.
c
c     (3) This routine does not modify the vdbs.
c
c     Glossary:
c     --------
c     dmin, dmax: subrange
c     reverse=-1 iff loading dvar in reverse order
c
c**********************************************************************

#include "drscom.h"
#include "drsdef.h"
#include "cycle.h"

      integer getdim,getvdim,savevdbs,restvdbs,setdim
      integer reverse

#if defined(__alpha)
      external d_floor
#endif

#ifdef hpux
#ifdef __linux
      double precision n,d_floor
#else
#ifndef ibm
      double precision n,floor
#else
      double precision n,d_floor
#endif
#endif
#else
      double precision n,d_floor
#endif

      getcdim=IDRS_SUCCESS

      getcdim=getdim(ndim,name,units,dtype,idlen,dum,dum)
      if (getcdim.ne.IDRS_SUCCESS) go to 9000

c     if not being used with getslab, just default to getvdim
      if (usecycle.eq.0) then
         getcdim=getvdim(ndim,source,title,reqlen,dvar,retlen)
         go to 9000
      endif

c     find the corresponding file dimension index

      do 50 i=1,nda
         if(ip(i).eq.ndim) then
            ipp=i
            go to 60
         endif
 50   continue
      getcdim=IDRS_BADDIM
      go to 9000
 60   continue

c     save the vdbs, since we will be clobbering them with
c     setdim calls to specify the subranges

      getcdim=savevdbs(isavbuf)
      if (getcdim.ne.IDRS_SUCCESS) go to 8000

c     if dimension is a cycle dimension ...
         
      if(cycle(ndim).ne.0.0) then

c     get the actual file dimension range
         if(dtype.eq.IDRS_EQUALLY_SPACED) then
            dfe=dfa(1,ipp)
            dle=dla(1,ipp)
         else
            dfe=dfa2(ipp)
            dle=dla2(ipp)
         endif

c     the algorithm for generating subranges (the same as is used in
c     getslab) requires that dfe <= dle, and that fe <= le.
         
         if(dle .lt. dfe) then
            dtemp=dfe
            dfe=dle
            dle=dtemp
         endif
         ufe=reqcyfe(ndim)
         ule=reqcyle(ndim)
         if(ule .lt. ufe) then
            dtemp=ufe
            ufe=ule
            ule=dtemp
            reverse=-1
         else
            reverse=1
         endif
         ucycle=cycle(ndim)
         istart=1
         iend=reqlen
         retlen=0

c     loop through the subranges

#ifdef hpux
#if defined(ibm)||defined(__linux)
         n=-d_floor(dble(-(ufe-dle)/ucycle))
#else
         n=-floor(%val(dble(-(ufe-dle)/ucycle)))
#endif
#else 
         n=-d_floor(dble(-(ufe-dle)/ucycle))
#endif

         dmin=ufe-n*ucycle

c     *** do ... ***

 100     continue
         if(ule .lt. (dfe+(n+1)*ucycle)) then
            dmax=ule-n*ucycle
         else
            dmax=dle
         endif

c     set the dimension range to the generated subrange [dmin,dmax]
c     and get the subrange

         getcdim=setdim(ndim,name,units,0,dmin,dmax)
         if(reqlen.gt.0) then
            ireqlen = abs(iend-istart)+1
         else
            ireqlen = 0
         endif
         getcdim=getvdim(ndim,source,title,
     $        ireqlen,dvar(istart),
     $        isubret)
         if (isubret.le.0) then
            retlen=0
            getcdim=IDRS_BADLEN
            go to 8000
         elseif(getcdim.ne.IDRS_SUCCESS) then
            go to 8000
         else
            retlen=retlen+isubret
         endif

c     move the read values into the proper place in the dimension var,
c     and adjust for cycle

         if (reverse .eq. 1) then
            do 200 i=1,isubret
               j=istart+i-1
               dvar(j)=dvar(j)+n*ucycle
 200        continue
            istart=istart+isubret
         else

c     data was returned in reverse order, so flip it back ...

            do 300 i=1,isubret/2
               dtemp=dvar(i)
               dvar(i)=dvar(isubret-i+1)
               dvar(isubret-i+1)=dtemp
 300        continue

c     ... and shift into place, adjusting for cycle

            do 350 i=1,isubret
               dvar(iend-i+1)=dvar(istart+isubret-i)+n*ucycle
 350        continue
            iend=iend-isubret
         endif

         n=n+1.0
         dmin=dfe

c     *** enddo ***

         if (ule .ge. (dfe+n*ucycle)) go to 100

c     if data reversed and does not fill dvar, shift to left

         if(reverse.eq.-1 .and. retlen.lt.reqlen) then
            ishift=reqlen-retlen
            do 400 i=1,retlen
               dvar(i)=dvar(i+ishift)
 400        continue
         endif
         
c     dimension is not a cycle dimension; just use getvdim
      else
         getcdim=setdim(ndim,name,units,0,
     $        reqcyfe(ndim),reqcyle(ndim))
         getcdim=getvdim(ndim,source,title,reqlen,dvar,retlen)
         if (getcdim.ne.IDRS_SUCCESS) go to 8000
      endif

 8000 continue

c     restore the vdbs

      getcdim=restvdbs(isavbuf)
      
 9000 continue
      call drsrout('getcdim',getcdim)
      return
      end
