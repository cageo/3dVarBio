subroutine rcfl_x_ad( im, jm, km, imax, al, bt, fld, inx, imx)
  
  !---------------------------------------------------------------------------
  !                                                                          !
  !    Copyright 2018 Anna Teruzzi, OGS, Trieste                         !
  !                                                                          !
  !    This file is part of 3DVarBio.
  !    3DVarBio is based on OceanVar (Dobricic, 2006)                                          !
  !                                                                          !
  !    3DVarBio is  free software: you can redistribute it and/or modify.     !
  !    it under the terms of the GNU General Public License as published by  !
  !    the Free Software Foundation, either version 3 of the License, or     !
  !    (at your option) any later version.                                   !
  !                                                                          !
  !    3DVarBio is  distributed in the hope that it will be useful,           !
  !    but WITHOUT ANY WARRANTY; without even the implied warranty of        !
  !    MERCHANTABILITY or FITNESS FOR a_rcx PARTICULAR PURPOSE.  See the         !
  !    GNU General Public License for more details.                          !
  !                                                                          !
  !    You should have received a_rcx copy of the GNU General Public License     !
  !    along with OceanVar.  If not, see <http://www.gnu.org/licenses/>.       !
  !                                                                          !
  !--------------------------------------------------------------------------- 
  
  !-----------------------------------------------------------------------
  !                                                                      !
  ! Recursive filter in x direction - adjoint
  !                                                                      !
  ! Version 1: A. Teruzzi 2018                                           !
  !-----------------------------------------------------------------------
  
  use set_knd
  use cns_str
  use rcfl
  use grd_str
  use mpi_str

  implicit none
  
  INTEGER(i4)    :: im, jm, km, imax
  
  REAL(r8)       :: fld(im,jm,km)
  REAL(r8)       :: al(jm,imax,km), bt(jm,imax,km)
  INTEGER(i4)    :: inx(im,jm,km), imx(km)
  
  
  INTEGER(i4)    :: i,j,k, ktr
  INTEGER(i4)    :: indSupWP
  INTEGER nthreads, tid
  integer :: OMP_GET_NUM_THREADS, OMP_GET_THREAD_NUM
  
  tid = 1
  !$OMP PARALLEL  &
  !$OMP PRIVATE(k,j,i,ktr,indSupWP,tid)
  !$  tid      = OMP_GET_THREAD_NUM()+1
  
  !$OMP DO
  do k=1,km
     
     a_rcx(:,:,tid) = 0.0
     b_rcx(:,:,tid) = 0.0
     c_rcx(:,:,tid) = 0.0
     
     do j=1,jm
        do i=1,im
           c_rcx(j,inx(i,j,k),tid) = fld(i,j,k)
        enddo
     enddo
     alp_rcx(:,:,tid) = al(:,:,k)
     bta_rcx(:,:,tid) = bt(:,:,k)
     
     do ktr = 1,rcf%ntr
        
        ! negative direction 
        b_rcx(:,:,tid) = 0.0
        
        do j=1,imx(k)-1
           c_rcx(:,j+1,tid) = c_rcx(:,j+1,tid) + bta_rcx(:,j,tid)*c_rcx(:,j,tid)
           b_rcx(:,j,tid)   = (1.-bta_rcx(:,j,tid))*c_rcx(:,j,tid)
        enddo

        
        if( ktr.eq.1 )then
           b_rcx(:,imx(k),tid) = b_rcx(:,imx(k),tid) + c_rcx(:,imx(k),tid) / (1.+bta_rcx(:,imx(k),tid))
        else
           b_rcx(:,imx(k),tid) = b_rcx(:,imx(k),tid) + (1.-bta_rcx(:,imx(k),tid)) * c_rcx(:,imx(k),tid) / (1.-bta_rcx(:,imx(k),tid)**2)**2
           b_rcx(:,imx(k)-1,tid) = b_rcx(:,imx(k)-1,tid) - (1.-bta_rcx(:,imx(k),tid)) &
                * bta_rcx(:,imx(k),tid)**3 * c_rcx(:,imx(k),tid) / (1.-bta_rcx(:,imx(k),tid)**2)**2
        endif

        ! positive direction 
        a_rcx(:,:,tid) = 0.0
        
        do j=imx(k),2,-1
           b_rcx(:,j-1,tid) = b_rcx(:,j-1,tid) + alp_rcx(:,j,tid)*b_rcx(:,j,tid)
           a_rcx(:,j,tid) = a_rcx(:,j,tid) + (1.-alp_rcx(:,j,tid))*b_rcx(:,j,tid)
        enddo
        
        
        if( ktr.eq.1 )then
           a_rcx(:,1,tid) = a_rcx(:,1,tid) + (1.-alp_rcx(:,1,tid)) * b_rcx(:,1,tid)
        elseif( ktr.eq.2 )then
           a_rcx(:,1,tid) = a_rcx(:,1,tid) + b_rcx(:,1,tid) / (1.+alp_rcx(:,1,tid))
        else
           a_rcx(:,1,tid) = a_rcx(:,1,tid) + (1.-alp_rcx(:,1,tid)) * b_rcx(:,1,tid) / (1.-alp_rcx(:,1,tid)**2)**2
           a_rcx(:,2,tid) = a_rcx(:,2,tid) - (1.-alp_rcx(:,1,tid)) * alp_rcx(:,1,tid)**3 * b_rcx(:,1,tid) / (1.-alp_rcx(:,1,tid)**2)**2
        endif

        
        c_rcx(:,:,tid) = a_rcx(:,:,tid)
        
     enddo
     
     ! This way fills land points with some values.
     ! We prefer not investigate at the moment and use only the water points
     do j=1,localCol
        do i=1,GlobalRow
           if(grd%global_msk(i,j + GlobalColOffset,1).eq.1) then
              fld(i,j,k) = c_rcx(j,inx(i,j,k),tid)
           end if
        end do
     end do
     
  enddo
  !$OMP END DO
  !$OMP END PARALLEL
  
  
  
end subroutine rcfl_x_ad
