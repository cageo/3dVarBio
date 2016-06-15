subroutine ver_hor_ad

!---------------------------------------------------------------------------
!                                                                          !
!    Copyright 2006 Srdjan Dobricic, CMCC, Bologna                         !
!                                                                          !
!    This file is part of OceanVar.                                          !
!                                                                          !
!    OceanVar is free software: you can redistribute it and/or modify.     !
!    it under the terms of the GNU General Public License as published by  !
!    the Free Software Foundation, either version 3 of the License, or     !
!    (at your option) any later version.                                   !
!                                                                          !
!    OceanVar is distributed in the hope that it will be useful,           !
!    but WITHOUT ANY WARRANTY; without even the implied warranty of        !
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         !
!    GNU General Public License for more details.                          !
!                                                                          !
!    You should have received a copy of the GNU General Public License     !
!    along with OceanVar.  If not, see <http://www.gnu.org/licenses/>.       !
!                                                                          !
!---------------------------------------------------------------------------

!-----------------------------------------------------------------------
!                                                                      !
! Transformation from physical to control space                        !
!                                                                      !
! Version 1: S.Dobricic 2006                                           !
! Version 2: S.Dobricic 2007                                           !
!     Symmetric calculation in presence of coastal boundaries          !
!     eta, tem, and sal are here temporary arrays                      !
! Version 3: A.Teruzzi 2013                                            !
!     Smoothing of the solution at d<200m                              !
!-----------------------------------------------------------------------


 use set_knd
 use grd_str
 use eof_str
 use cns_str
 use drv_str
 use obs_str

 implicit none

 INTEGER(i4)    :: i,j,k, ione, l
 INTEGER        :: jp,nestr
 REAL(r8)       :: chlapp(8),chlsum

! ---
! Correction is zero out of mask (for correction near the coast)
  if(drv%biol.eq.1) then
   do k=1,grd%km
    do j=1,grd%jm
     do i=1,grd%im
       if (grd%msk(i,j,k).eq.0) then
          grd%chl_ad(i,j,k,:) = 0.
       endif
      enddo  !i
     enddo  !j
    enddo  !k
   endif



!goto 103 ! No Vh
 ione = 1


#ifdef __FISICA

! ---
! Divergence damping
    if(drv%dda(drv%ktr) .eq. 1) then
       call div_dmp_ad
    endif

! ---
! Velocity
       call get_vel_ad

! ---
! Barotropic model
    if(drv%bmd(drv%ktr) .eq. 1) then
       call bar_mod_ad
    endif

! ---
! Bouyancy force
       call get_byg_ad

#endif

! ---
! Scale for boundaries
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)        &
       grd%eta_ad(:,:)   = grd%eta_ad(:,:)   * grd%fct(:,:,1)
    grd%tem_ad(:,:,:) = grd%tem_ad(:,:,:) * grd%fct(:,:,:)
    grd%sal_ad(:,:,:) = grd%sal_ad(:,:,:) * grd%fct(:,:,:)
  endif


  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
    grd%chl_ad(:,:,k,l)   = grd%chl_ad(:,:,k,l) * grd%fct(:,:,k) 
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif


 if(drv%mask(drv%ktr) .gt. 1) then

! ---
! Load temporary arrays
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
       if(drv%bmd(drv%ktr) .ne. 1)      &
          grd%eta(:,:  )    = grd%eta_ad(:,:  )
          grd%tem(:,:,:)    = grd%tem_ad(:,:,:)
          grd%sal(:,:,:)    = grd%sal_ad(:,:,:)
  endif
  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
          grd%chl(:,:,k,l)    = grd%chl_ad(:,:,k,l) 
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif

! ---
! x direction
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)         &
       call rcfl_x( grd%im, grd%jm,   ione, grd%imax, grd%aex, grd%bex, grd%eta, grd%inx, grd%imx)
    call rcfl_x( grd%im, grd%jm, grd%km, grd%imax, grd%aex, grd%bex, grd%tem, grd%inx, grd%imx)
    call rcfl_x( grd%im, grd%jm, grd%km, grd%imax, grd%aex, grd%bex, grd%sal, grd%inx, grd%imx)
  endif
   if(drv%biol.eq.1) then
    call rcfl_x( grd%im, grd%jm, grd%km*grd%nchl, grd%imax, grd%aex, grd%bex, grd%chl, grd%inx, grd%imx)
   endif
! ---
! Scale by the scaling factor
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)         &
       grd%eta(:,:)   = grd%eta(:,:)   * grd%scx(:,:)
   do k=1,grd%km
    grd%tem(:,:,k) = grd%tem(:,:,k) * grd%scx(:,:)
    grd%sal(:,:,k) = grd%sal(:,:,k) * grd%scx(:,:)
   enddo
  endif
  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
    grd%chl(:,:,k,l) = grd%chl(:,:,k,l) * grd%scx(:,:) 
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif
! ---
! y direction
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)         &
       call rcfl_y( grd%im, grd%jm,   ione, grd%jmax, grd%aey, grd%bey, grd%eta, grd%jnx, grd%jmx)
    call rcfl_y( grd%im, grd%jm, grd%km, grd%jmax, grd%aey, grd%bey, grd%tem, grd%jnx, grd%jmx)
    call rcfl_y( grd%im, grd%jm, grd%km, grd%jmax, grd%aey, grd%bey, grd%sal, grd%jnx, grd%jmx)
  endif
   if(drv%biol.eq.1) then
    call rcfl_y( grd%im, grd%jm, grd%km*grd%nchl, grd%jmax, grd%aey, grd%bey, grd%chl, grd%jnx, grd%jmx)
   endif
! ---
! Scale by the scaling factor
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)         &
       grd%eta(:,:)   = grd%eta(:,:)   * grd%scy(:,:)
   do k=1,grd%km
    grd%tem(:,:,k) = grd%tem(:,:,k) * grd%scy(:,:)
    grd%sal(:,:,k) = grd%sal(:,:,k) * grd%scy(:,:)
   enddo
  endif
  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
    grd%chl(:,:,k,l) = grd%chl(:,:,k,l) * grd%scy(:,:) 
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif

 endif

! ---
! Scale by the scaling factor
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)        &
       grd%eta_ad(:,:)   = grd%eta_ad(:,:)   * grd%scy(:,:)
   do k=1,grd%km
    grd%tem_ad(:,:,k) = grd%tem_ad(:,:,k) * grd%scy(:,:)
    grd%sal_ad(:,:,k) = grd%sal_ad(:,:,k) * grd%scy(:,:)
   enddo
  endif
  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
    grd%chl_ad(:,:,k,l) = grd%chl_ad(:,:,k,l) * grd%scy(:,:) 
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif

! ---
! y direction
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)        &
       call rcfl_y_ad( grd%im, grd%jm,   ione, grd%jmax, grd%aey, grd%bey, grd%eta_ad, grd%jnx, grd%jmx)
    call rcfl_y_ad( grd%im, grd%jm, grd%km, grd%jmax, grd%aey, grd%bey, grd%tem_ad, grd%jnx, grd%jmx)
    call rcfl_y_ad( grd%im, grd%jm, grd%km, grd%jmax, grd%aey, grd%bey, grd%sal_ad, grd%jnx, grd%jmx)
  endif
   if(drv%biol.eq.1) then
    call rcfl_y_ad( grd%im, grd%jm, grd%km*grd%nchl, grd%jmax, grd%aey, grd%bey, grd%chl_ad, grd%jnx, grd%jmx)
!    write(*,*) 'AFTER rcfl_y_ad', grd%chl_ad(71,12,1,1)
   endif

! ---
! Scale by the scaling factor
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)        &
       grd%eta_ad(:,:)   = grd%eta_ad(:,:)   * grd%scx(:,:)
   do k=1,grd%km
    grd%tem_ad(:,:,k) = grd%tem_ad(:,:,k) * grd%scx(:,:)
    grd%sal_ad(:,:,k) = grd%sal_ad(:,:,k) * grd%scx(:,:)
   enddo
  endif
  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
    grd%chl_ad(:,:,k,l) = grd%chl_ad(:,:,k,l) * grd%scx(:,:) 
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif

! ---
! x direction
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)        &
       call rcfl_x_ad( grd%im, grd%jm,   ione, grd%imax, grd%aex, grd%bex, grd%eta_ad, grd%inx, grd%imx)
    call rcfl_x_ad( grd%im, grd%jm, grd%km, grd%imax, grd%aex, grd%bex, grd%tem_ad, grd%inx, grd%imx)
    call rcfl_x_ad( grd%im, grd%jm, grd%km, grd%imax, grd%aex, grd%bex, grd%sal_ad, grd%inx, grd%imx)
  endif
  if(drv%biol.eq.1) then
    call rcfl_x_ad( grd%im, grd%jm, grd%km*grd%nchl, grd%imax, grd%aex, grd%bex, grd%chl_ad, grd%inx, grd%imx)
  endif


! ---
! Average
 if(drv%mask(drv%ktr) .gt. 1) then
  if(drv%biol.eq.0 .or. drv%bphy.eq.1)then
    if(drv%bmd(drv%ktr) .ne. 1)         &
        grd%eta_ad(:,:  )   = (grd%eta_ad(:,:  ) + grd%eta(:,:  ) ) * 0.5
        grd%tem_ad(:,:,:)   = (grd%tem_ad(:,:,:) + grd%tem(:,:,:) ) * 0.5
        grd%sal_ad(:,:,:)   = (grd%sal_ad(:,:,:) + grd%sal(:,:,:) ) * 0.5

  endif
  if(drv%biol.eq.1) then
   do l=1,grd%nchl
!$OMP PARALLEL  &
!$OMP PRIVATE(k)
!$OMP DO
   do k=1,grd%km
        grd%chl_ad(:,:,k,l)  = (grd%chl_ad(:,:,k,l) + grd%chl(:,:,k,l) ) * 0.5
   enddo
!$OMP END DO
!$OMP END PARALLEL  
   enddo
  endif
 endif

!anna sreduction of correction d<200m
   do l=1,grd%nchl
   do j=2,grd%jm-1  ! OMP
   do i=2,grd%im-1
    if ((grd%msk(i,j,chl%kdp).eq.0).and.  &
        (grd%msk(i,j,1).eq.1)) then
      do k=1,grd%km
       if(grd%msk(i,j,k).eq.1) then
         chlapp(1)=grd%chl(i+1,j,  k,l)
         chlapp(2)=grd%chl(i-1,j,  k,l)
         chlapp(3)=grd%chl(i,  j+1,k,l)
         chlapp(4)=grd%chl(i,  j-1,k,l)
         chlapp(5)=grd%chl(i+1,j+1,k,l)
         chlapp(6)=grd%chl(i+1,j-1,k,l)
         chlapp(7)=grd%chl(i-1,j+1,k,l)
         chlapp(8)=grd%chl(i-1,j-1,k,l)
         nestr=0
         do jp=1,8
           if ((chlapp(jp).ne.0).and.(chlapp(jp)/chlapp(jp).eq.1)) then
             nestr=nestr+1;
           endif
         enddo ! do on jp
         if (nestr.ne.0) then
         grd%chl_ad(i+1,j,  k,l)=grd%chl_ad(i+1,j,  k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i-1,j,  k,l)=grd%chl_ad(i-1,j,  k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i,  j+1,k,l)=grd%chl_ad(i  ,j+1,k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i,  j-1,k,l)=grd%chl_ad(i  ,j-1,k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i+1,j+1,k,l)=grd%chl_ad(i+1,j+1,k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i+1,j-1,k,l)=grd%chl_ad(i+1,j-1,k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i-1,j+1,k,l)=grd%chl_ad(i-1,j+1,k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i-1,j-1,k,l)=grd%chl_ad(i-1,j-1,k,l)+  &
                                  .1*grd%chl_ad(i,j,k,l)/nestr
         grd%chl_ad(i,j,k,l)=0.
         endif
       endif !if on k
      enddo ! do on k
    endif ! if on grd%chl(i,j,1,l)
   enddo ! do on i
   enddo ! do on j
   enddo ! do on l


 

!103 continue
! ---
! Vertical EOFs           
    call veof_ad


end subroutine ver_hor_ad