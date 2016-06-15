subroutine obsop_ad

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
! Apply observational operators - adjoint
!                                                                      !
! Version 1: S.Dobricic 2006                                           !
!-----------------------------------------------------------------------


 use set_knd
 use obs_str

 implicit none

  obs%k = 0

#ifdef __FISICA
! ---
! Satellite observations of SLA
  call obs_sla_ad

! ---
! ARGO observations 
  call obs_arg_ad

! ---
! XBT observations 
  call obs_xbt_ad

! ---
! Glider observations 
  call obs_gld_ad

! ---
! Observations of Argo trajectories
  if(tra%no.gt.0) call obs_tra_ad

! ---
! Observations of trajectories of surface drifters
  if(trd%no.gt.0) call obs_trd_ad

! ---
! Observations of velocity from drifters
  call obs_vdr_ad

! ---
! Observations of velocity from gliders
  call obs_gvl_ad

#endif
! ---
! Observations of chlorophyll
  call obs_chl_ad

end subroutine obsop_ad