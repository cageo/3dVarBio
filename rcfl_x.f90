subroutine rcfl_x( im, jm, km, imax, al, bt, fld, inx, imx)
  
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
  !    MERCHANTABILITY or FITNESS FOR a_rcx PARTICULAR PURPOSE.  See the         !
  !    GNU General Public License for more details.                          !
  !                                                                          !
  !    You should have received a_rcx copy of the GNU General Public License     !
  !    along with OceanVar.  If not, see <http://www.gnu.org/licenses/>.       !
  !                                                                          !
  !---------------------------------------------------------------------------
  
  !-----------------------------------------------------------------------
  !                                                                      !
  ! Recursive filter in x direction                                      !
  !                                                                      !
  ! Version 1: S.Dobricic 2006                                           !
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
  
  integer :: MyStatus(MPI_STATUS_SIZE)
  integer :: SendCounter, RecCounter, MyLevel, ReadyProc, ComputedLevel, ierr
  integer :: EndIndex, UpdateIndex
  real(8), allocatable, dimension(:,:,:) :: RecArr, ToSend

  tid=1
  !$OMP PARALLEL &
  !$OMP PRIVATE(k,j,i,ktr,indSupWP,tid)
  !$ tid      = OMP_GET_THREAD_NUM()+1
  !$OMP DO
  
  if(MyRank .eq. 0) then

    ALLOCATE(ToSend(im,jm,LevSize))
    ALLOCATE(RecArr(im,jm,LevSize))
    SendCounter = 1
    RecCounter  = 1
    do while(RecCounter .le. km)
      
      call MPI_Recv(RecArr, im*jm*LevSize, MPI_REAL8, MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD, MyStatus, ierr)
      ReadyProc = MyStatus(MPI_SOURCE)
      ComputedLevel = MyStatus(MPI_TAG)

      if(SendCounter .le. NLevels*LevSize) then
        do k=1,LevSize 
          do j=1,jm
            do i=1,im
              ToSend(i,j,k) = fld(i,j,SendCounter+k-1)
            enddo
          enddo
        enddo
        call MPI_Send(ToSend, im*jm*LevSize, MPI_REAL8, ReadyProc, SendCounter, MPI_COMM_WORLD, ierr)
        SendCounter = SendCounter + LevSize

      else if(SendCounter .le. km) then ! case of Rest != 0
        do k=1,LevRest
          do j=1,jm
            do i=1,im
              ToSend(i,j,k) = fld(i,j,SendCounter+k-1)
            enddo
          enddo
        enddo

        call MPI_Send(ToSend, im*jm*LevSize, MPI_REAL8, ReadyProc, SendCounter, MPI_COMM_WORLD, ierr)
        SendCounter = km+1

      else
        ! Killing ReadyProc
        call MPI_Send(ToSend, im*jm*LevSize, MPI_REAL8, ReadyProc, km+1, MPI_COMM_WORLD, ierr)
      endif

     if(ComputedLevel .gt. 0) then
        if(ComputedLevel .le. NLevels*LevSize) then
          RecCounter = RecCounter + LevSize
          do k=1,LevSize
            do j=1,jm
              do i=1,im
                  fld(i,j,ComputedLevel+k-1) = RecArr(i,j,k)
              enddo
            enddo
          enddo
        else if (ComputedLevel .le. km) then
          RecCounter = RecCounter + LevRest
          do k=1,LevRest
            do j=1,jm
              do i=1,im
                  fld(i,j,ComputedLevel+k-1) = RecArr(i,j,k)
              enddo
            enddo
          enddo
        endif
     endif

    enddo

    DEALLOCATE(ToSend, RecArr)

  else
    
    MyLevel = 0;
    ALLOCATE(RecArr(im,jm,LevSize))
    call MPI_Send(RecArr, im*jm*LevSize, MPI_REAL8, 0, MyLevel, MPI_COMM_WORLD, ierr)

    do while(.true.)
      call MPI_Recv(RecArr, im*jm*LevSize, MPI_REAL8, 0, MPI_ANY_TAG, MPI_COMM_WORLD, MyStatus, ierr)

      MyLevel = MyStatus(MPI_TAG)

      if(MyLevel .le. km) then
        if(MyLevel .le. NLevels*LevSize) then
          EndIndex = MyLevel + LevSize - 1
        else
          EndIndex = MyLevel + LevRest - 1
        endif

        do k=MyLevel,EndIndex

          UpdateIndex = k-MyLevel+1

          a_rcx(:,:,tid) = 0.0
          b_rcx(:,:,tid) = 0.0
          c_rcx(:,:,tid) = 0.0
      
          do j=1,jm
            do i=1,im
              a_rcx(j,inx(i,j,k),tid) = RecArr(i,j,UpdateIndex)
            enddo
          enddo
          alp_rcx(:,:,tid) = al(:,:,k)
          bta_rcx(:,:,tid) = bt(:,:,k)
      
          do ktr = 1,rcf%ntr
          
            ! positive direction
            if( ktr.eq.1 )then
              b_rcx(:,1,tid) = (1.-alp_rcx(:,1,tid)) * a_rcx(:,1,tid)
            elseif( ktr.eq.2 )then
              b_rcx(:,1,tid) = a_rcx(:,1,tid) / (1.+alp_rcx(:,1,tid))
            else
              b_rcx(:,1,tid) = (1.-alp_rcx(:,1,tid)) * (a_rcx(:,1,tid)-alp_rcx(:,1,tid)**3 * a_rcx(:,2,tid)) / (1.-alp_rcx(:,1,tid)**2)**2
            endif
            
            do j=2,imx(k)
              b_rcx(:,j,tid) = alp_rcx(:,j,tid)*b_rcx(:,j-1,tid) + (1.-alp_rcx(:,j,tid))*a_rcx(:,j,tid)
            enddo
          
            ! negative direction
            if( ktr.eq.1 )then
              c_rcx(:,imx(k),tid) = b_rcx(:,imx(k),tid) / (1.+bta_rcx(:,imx(k),tid))
            else
              c_rcx(:,imx(k),tid) = (1.-bta_rcx(:,imx(k),tid)) * &
                    (b_rcx(:,imx(k),tid)-bta_rcx(:,imx(k),tid)**3 * b_rcx(:,imx(k)-1,tid)) / (1.-bta_rcx(:,imx(k),tid)**2)**2
            endif
            
            do j=imx(k)-1,1,-1
              c_rcx(:,j,tid) = bta_rcx(:,j,tid)*c_rcx(:,j+1,tid) + (1.-bta_rcx(:,j,tid))*b_rcx(:,j,tid)
            enddo
          
            a_rcx(:,:,tid) = c_rcx(:,:,tid)

          enddo
      
          do indSupWP=1,nSurfaceWaterPoints
            i = SurfaceWaterPoints(1,indSupWP)
            j = SurfaceWaterPoints(2,indSupWP)
            RecArr(i,j,UpdateIndex) = a_rcx(j,inx(i,j,k),tid)
          enddo

        enddo

        call MPI_Send(RecArr, im*jm*LevSize, MPI_REAL8, 0, MyLevel, MPI_COMM_WORLD, ierr)

      else
        exit
      endif
    enddo

    DEALLOCATE(RecArr)
  !$OMP END DO
  !$OMP END PARALLEL
  
  endif
  call  MPI_Barrier(MPI_COMM_WORLD, ierr)
  

end subroutine rcfl_x
