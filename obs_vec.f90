subroutine obs_vec


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
! Create the observational vector                                      !
!                                                                      !
! Version 1: S.Dobricic 2006                                           !
!-----------------------------------------------------------------------


 use set_knd
 use drv_str
 use obs_str

 implicit none

  INTEGER(i4)    ::  k, i

! -------
! Define observational vector

    obs%no = sla%nc + arg%nc + xbt%nc + gld%nc + 2 * tra%nc + 2 * trd%nc  &
           + vdr%nc + gvl%nc + chl%nc

   write(drv%dia,*) ' Total number of observations: ', obs%no

   ALLOCATE ( obs%inc(obs%no)) ; obs%inc = huge(obs%inc(1))
   ALLOCATE ( obs%amo(obs%no)) ; obs%amo = huge(obs%amo(1))
   ALLOCATE ( obs%res(obs%no)) ; obs%res = huge(obs%res(1))
   ALLOCATE ( obs%err(obs%no)) ; obs%err = huge(obs%err(1))
   ALLOCATE ( obs%gra(obs%no)) ; obs%gra = huge(obs%gra(1))


   k=0

! SLA observations
   do i=1,sla%no
    if(sla%flc(i).eq.1)then
     k=k+1
     obs%res(k) = sla%res(i)
     obs%err(k) = sla%err(i)
    endif
   enddo

! ARGO observations
   do i=1,arg%no
    if(arg%flc(i).eq.1)then
     k=k+1
     obs%res(k) = arg%res(i)
     obs%err(k) = arg%err(i)
    endif
   enddo

! XBT observations
   do i=1,xbt%no
    if(xbt%flc(i).eq.1)then
     k=k+1
     obs%res(k) = xbt%res(i)
     obs%err(k) = xbt%err(i)
    endif
   enddo

! Glider observations
   do i=1,gld%no
    if(gld%flc(i).eq.1)then
     k=k+1
     obs%res(k) = gld%res(i)
     obs%err(k) = gld%err(i)
    endif
   enddo

! Argo trajectory observations
   do i=1,tra%no
    if(tra%flc(i).eq.1)then
     k=k+1
     obs%res(k) = tra%rex(i)
     obs%err(k) = tra%erx(i)
    endif
   enddo
   do i=1,tra%no
    if(tra%flc(i).eq.1)then
     k=k+1
     obs%res(k) = tra%rey(i)
     obs%err(k) = tra%ery(i)
    endif
   enddo

! Trajectory observations of surface drifters
   do i=1,trd%no
    if(trd%flc(i).eq.1)then
     k=k+1
     obs%res(k) = trd%rex(i)
     obs%err(k) = trd%erx(i)
    endif
   enddo
   do i=1,trd%no
    if(trd%flc(i).eq.1)then
     k=k+1
     obs%res(k) = trd%rey(i)
     obs%err(k) = trd%ery(i)
    endif
   enddo

! Observations of drifter velocities
   do i=1,vdr%no
    if(vdr%flc(i).eq.1)then
     k=k+1
     obs%res(k) = vdr%res(i)
     obs%err(k) = vdr%err(i)
    endif
   enddo

! Observations of glider velocities
   do i=1,gvl%no
    if(gvl%flc(i).eq.1)then
     k=k+1
     obs%res(k) = gvl%res(i)
     obs%err(k) = gvl%err(i)
    endif
   enddo

! Observations of chlorophyll
   do i=1,chl%no
    if(chl%flc(i).eq.1)then
     k=k+1
     obs%res(k) = chl%res(i)
     obs%err(k) = chl%err(i)
    endif
   enddo


end subroutine obs_vec