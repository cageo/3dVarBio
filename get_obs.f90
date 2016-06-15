subroutine get_obs

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
! Load observations                                                    !
!                                                                      !
! Version 1: S.Dobricic 2006                                           !
!-----------------------------------------------------------------------


 use set_knd
 use obs_str

 implicit none

#ifdef __FISICA
! ----
! Load SLA observations
  call get_obs_sla

! ----
! Load ARGO observations
  call get_obs_arg

! ----
! Load XBT observations
  call get_obs_xbt

! ----
! Load glider observations
  call get_obs_gld

! ----
! Load Argo trajectory observations
  call get_obs_tra

! ----
! Load trajectory observations of surface drifters
  call get_obs_trd

! ----
! Load observations of velocity by drifters
  call get_obs_vdr

! ----
! Load observations of velocity by drifters
  call get_obs_gvl

#endif

! ----
! Load observations of chlorophyll
  call get_obs_chl

end subroutine get_obs