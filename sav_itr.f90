subroutine sav_itr


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
! Save the result on the coarse grid                                   !
!                                                                      !
! Version 1: S.Dobricic 2006                                           !
!-----------------------------------------------------------------------


 use set_knd
 use drv_str
 use obs_str
 use grd_str
 use eof_str
 use ctl_str
 use bmd_str
 use rcfl

 implicit none

! ---
! Save grid dimensions

   drv%im = grd%im
   drv%jm = grd%jm
! Save eigenvalues
   if (1.eq.0) then ! We do not know the reason of these lines
   ALLOCATE ( drv%ro(drv%im,drv%jm,ros%neof))    ; drv%ro   (:,:,:) = grd%ro   (:,:,:)
   ALLOCATE ( drv%ro_ad(drv%im,drv%jm,ros%neof)) ; drv%ro_ad(:,:,:) = grd%ro_ad(:,:,:)
   ALLOCATE ( drv%msk(drv%im,drv%jm))            ; drv%msk  (:,:)   = grd%msr  (:,:,1)
   endif
! ---
! Deallocate everithing related to the old grid

! Grid structure
     DEALLOCATE ( grd%reg)
     DEALLOCATE ( grd%msk)
     DEALLOCATE ( grd%hgt)
     DEALLOCATE ( grd%f)
     if  (drv%bphy.eq.1) then
     DEALLOCATE ( grd%tem, grd%sal)
     DEALLOCATE ( grd%uvl, grd%vvl)
     DEALLOCATE ( grd%uvl_ad, grd%vvl_ad)
     DEALLOCATE ( grd%b_x, grd%b_y)
     DEALLOCATE ( grd%temb, grd%salb)
     DEALLOCATE ( grd%tem_ad, grd%sal_ad)
     DEALLOCATE ( grd%dns)
     DEALLOCATE ( grd%eta)
     DEALLOCATE ( grd%etab)
     DEALLOCATE ( grd%sla)
     DEALLOCATE ( grd%eta_ad)
     endif

     DEALLOCATE ( grd%bx, grd%by)
     DEALLOCATE ( grd%mdt )
     DEALLOCATE ( grd%lon, grd%lat, grd%dep)
     DEALLOCATE ( grd%dx, grd%dy, grd%dz)
     DEALLOCATE ( grd%dxdy)
     DEALLOCATE ( grd%alx )
     DEALLOCATE ( grd%aly )
     DEALLOCATE ( grd%btx )
     DEALLOCATE ( grd%bty )
     DEALLOCATE ( grd%scx )
     DEALLOCATE ( grd%scy )
     DEALLOCATE ( grd%msr )
     DEALLOCATE ( grd%imx, grd%jmx)
     DEALLOCATE ( grd%istp, grd%jstp)
     DEALLOCATE ( grd%inx, grd%jnx)
     DEALLOCATE ( grd%fct)
     DEALLOCATE ( grd%aex)
     DEALLOCATE ( grd%aey)
     DEALLOCATE ( grd%bex)
     DEALLOCATE ( grd%bey)
    if(drv%biol.eq.1) then
     DEALLOCATE ( grd%chl)
     DEALLOCATE ( grd%chl_ad)
    endif
! Observational vector
     DEALLOCATE ( obs%inc, obs%amo, obs%res)
     DEALLOCATE ( obs%err, obs%gra)
! Covariances structure
     DEALLOCATE ( grd%ro)
     DEALLOCATE ( grd%ro_ad)
     DEALLOCATE ( ros%evc, ros%eva )
     DEALLOCATE ( ros%cor )
! Control structure    
     DEALLOCATE( ctl%nbd, ctl%iwa)
     DEALLOCATE( ctl%x_c, ctl%g_c)
     DEALLOCATE( ctl%l_c, ctl%u_c)
     DEALLOCATE( ctl%wa, ctl%sg, ctl%sgo, ctl%yg, ctl%ygo)
     DEALLOCATE( ctl%ws, ctl%wy)
     DEALLOCATE( ctl%sy, ctl%ss, ctl%yy)
     DEALLOCATE( ctl%wt, ctl%wn, ctl%snd)
     DEALLOCATE( ctl%z_c, ctl%r_c, ctl%d_c, ctl%t_c)
     DEALLOCATE (SurfaceWaterpoints)



     DEALLOCATE ( a_rcx)
     DEALLOCATE ( b_rcx)
     DEALLOCATE ( c_rcx)
     DEALLOCATE ( a_rcy)
     DEALLOCATE ( b_rcy)
     DEALLOCATE ( c_rcy)
     DEALLOCATE ( alp_rcx)
     DEALLOCATE ( bta_rcx)
     DEALLOCATE ( alp_rcy)
     DEALLOCATE ( bta_rcy)
     DEALLOCATE (Dump_chl, Dump_vip, Dump_msk)

     write(*,*) ' DEALLOCATION DONE'
! Barotropic model
   if(drv%bmd(drv%ktr) .eq. 1) then
     DEALLOCATE ( bmd%itr)
     DEALLOCATE ( bmd%mst, bmd%msu, bmd%msv)
     DEALLOCATE ( bmd%hgt, bmd%hgu, bmd%hgv)
     DEALLOCATE ( bmd%dxu, bmd%dxv)
     DEALLOCATE ( bmd%dyu, bmd%dyv)
     DEALLOCATE ( bmd%a1, bmd%a2, bmd%a3)
     DEALLOCATE ( bmd%a4, bmd%a0, bmd%a00)
     DEALLOCATE ( bmd%bx, bmd%by)
     DEALLOCATE ( bmd%b_x, bmd%b_y)
     DEALLOCATE ( bmd%dns)
     DEALLOCATE ( bmd%bxby, bmd%rgh)
     DEALLOCATE ( bmd%etb, bmd%ub, bmd%vb)
     DEALLOCATE ( bmd%etn, bmd%un, bmd%vn)
     DEALLOCATE ( bmd%eta, bmd%ua, bmd%va)
     DEALLOCATE ( bmd%etm, bmd%um, bmd%vm)
     DEALLOCATE ( bmd%div, bmd%cu, bmd%cv)
     DEALLOCATE ( bmd%dux, bmd%duy)
     DEALLOCATE ( bmd%dvx, bmd%dvy)
     DEALLOCATE ( bmd%etx, bmd%ety)
   endif


end subroutine sav_itr