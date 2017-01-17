subroutine parallel_rdgrd

  use set_knd
  use drv_str
  use grd_str
  use filenames

  use mpi
  use mpi_str
  use pnetcdf
  use cns_str

  implicit none

  integer(i8) :: ierr, ncid
  integer(i8) :: jpreci, jprecj
  integer(i8) :: VarId
  real(r4), ALLOCATABLE          :: x3(:,:,:), x2(:,:), x1(:)

  integer(8) :: GlobalStart(3), GlobalCount(3)
  integer(KIND=MPI_OFFSET_KIND) MyOffset

  !
  ! open grid1.nc in read-only mode
  ierr = nf90mpi_open(MPI_COMM_WORLD, GRID_FILE, NF90_NOWRITE, MPI_INFO_NULL, ncid)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_open', ierr)

  !
  ! get grid dimensions
  !
  call MyGetDimension(ncid, 'im', MyOffset)
  GlobalRow = MyOffset

  call MyGetDimension(ncid, 'jm', MyOffset)
  GlobalCol = MyOffset

  call MyGetDimension(ncid, 'km', MyOffset)
  grd%km = MyOffset

  if(MyRank .eq. 0) then
     write(drv%dia,*)'Grid dimensions are: ',GlobalRow,GlobalCol,grd%km

     write(drv%dia,*) ' '
     write(drv%dia,*) 'Dom_Size'
     write(drv%dia,*) ' '
     write(drv%dia,*) ' number of processors following i : NumProcI   = ', NumProcI
     write(drv%dia,*) ' number of processors following j : NumProcJ   = ', NumProcJ
     write(drv%dia,*) ' '
     write(drv%dia,*) ' local domains : < or = NumProcI x NumProcJ number of processors   = ', NumProcIJ
     write(drv%dia,*) ' '

     WRITE(*,*) 'Dimension_Med_Grid'
     WRITE(*,*) ' '
     WRITE(*,*) ' GlobalRow  : first  dimension of global domain --> i ',GlobalRow
     WRITE(*,*) ' GlobalCol  : second dimension of global domain --> j ',GlobalCol
     WRITE(*,*) ' ReadDomDec : ',drv%ReadDomDec
     WRITE(*,*) ' '
  endif

  GlobalStart(:) = 1
  GlobalCount(1) = GlobalRow
  GlobalCount(2) = GlobalCol
  GlobalCount(3) = grd%km
  ALLOCATE(x3(GlobalRow, GlobalCol, grd%km))
  ALLOCATE(grd%global_msk(GlobalRow, GlobalCol, grd%km))
  ierr = nf90mpi_inq_varid (ncid, 'tmsk', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, GlobalStart, GlobalCount, x3)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all global_msk', ierr)
  grd%global_msk(:,:,:) = x3(:,:,:)
  DEALLOCATE(x3)

  ALLOCATE(x2(GlobalRow, GlobalCol))
  ALLOCATE(grd%dx(GlobalRow, GlobalCol))
  ALLOCATE(grd%dy(GlobalRow, GlobalCol))
  ALLOCATE(grd%istp(GlobalRow, GlobalCol))
  ALLOCATE(grd%jstp(GlobalRow, GlobalCol))

  ierr = nf90mpi_inq_varid (ncid, 'dx', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, GlobalStart, GlobalCount, x2)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all dx', ierr)
  grd%dx(:,:) = x2(:,:)

  ierr = nf90mpi_inq_varid (ncid, 'dy', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, GlobalStart, GlobalCount, x2)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all dy', ierr)
  grd%dy(:,:) = x2(:,:)

  grd%istp = int( rcf%L * rcf%efc / grd%dx(:,:) )+1
  grd%jstp = int( rcf%L * rcf%efc / grd%dy(:,:) )+1

  call DomainDecomposition
  DEALLOCATE(grd%dx, grd%dy)
  DEALLOCATE(grd%istp, grd%jstp)
  DEALLOCATE(x2)

  ALLOCATE(ChlExtended(grd%im+1, grd%jm+1, grd%nchl))
  ALLOCATE(SendLeft(grd%im), RecRight(grd%im))
  ALLOCATE(SendRight(grd%im), RecLeft(grd%im))
  ALLOCATE(SendTop(grd%jm), RecBottom(grd%jm))
  ALLOCATE(SendBottom(grd%jm), RecTop(grd%jm))

  ALLOCATE(ChlExtendedAD_4D(0:(grd%im+1), 0:(grd%jm+1), grd%km, grd%nchl))
  ALLOCATE(ChlExtended4D(0:(grd%im+1), 0:(grd%jm+1), grd%km, grd%nchl))
  ALLOCATE(SendLeft2D(grd%im, grd%km), RecRight2D(grd%im, grd%km))
  ALLOCATE(SendRight2D(grd%im, grd%km), RecLeft2D(grd%im, grd%km))
  ALLOCATE(SendTop2D(grd%jm, grd%km), RecBottom2D(grd%jm, grd%km))
  ALLOCATE(SendBottom2D(grd%jm, grd%km), RecTop2D(grd%jm, grd%km))

  ! print*, "Debugging", MyRank, "SC", SendCountY2D, "RC", RecCountY2D, "SD", SendDisplY2D, "RD", RecDisplY2D

  ! *****************************************************************************************
  ! *****************************************************************************************
  ! (almost) copy-paste from rdgrds.f90
  ! Allocate grid arrays

  ALLOCATE ( grd%reg(grd%im,grd%jm))        ; grd%reg = huge(grd%reg(1,1))
  ALLOCATE ( grd%msk(grd%im,grd%jm,grd%km)) ; grd%msk = huge(grd%msk(1,1,1))
  ALLOCATE ( grd%dep(grd%km))        ; grd%dep = huge(grd%dep(1))
  ALLOCATE ( grd%dx(grd%im,grd%jm))  ; grd%dx  = huge(grd%dx(1,1))
  ALLOCATE ( grd%dy(grd%im,grd%jm))  ; grd%dy  = huge(grd%dy(1,1))

  ALLOCATE ( grd%alx(GlobalRow,localCol) )         ; grd%alx  = huge(grd%alx(1,1))
  ALLOCATE ( grd%aly(localRow,GlobalCol) )         ; grd%aly  = huge(grd%aly(1,1))
  ALLOCATE ( grd%btx(GlobalRow,localCol) )         ; grd%btx  = huge(grd%btx(1,1))
  ALLOCATE ( grd%bty(localRow,GlobalCol) )         ; grd%bty  = huge(grd%bty(1,1))
  ALLOCATE ( grd%scx(GlobalRow,localCol) )         ; grd%scx  = huge(grd%scx(1,1))
  ALLOCATE ( grd%scy(localRow,GlobalCol) )         ; grd%scy  = huge(grd%scy(1,1))
  ALLOCATE ( grd%msr(grd%im,grd%jm,grd%km) )  ; grd%msr  = huge(grd%msr(1,1,1))
  ALLOCATE ( grd%imx(grd%km))                 ; grd%imx  = huge(grd%imx(1))
  ALLOCATE (  grd%jmx(grd%km))                ; grd%jmx  = huge(grd%jmx(1))
  ALLOCATE ( grd%istp(GlobalRow,localCol))         ; grd%istp = huge(grd%istp(1,1))
  ALLOCATE ( grd%jstp(localRow,GlobalCol))         ; grd%jstp = huge(grd%jstp(1,1))
  ALLOCATE ( grd%inx(GlobalRow,localCol,grd%km))   ; grd%inx  = huge(grd%inx(1,1,1))
  ALLOCATE ( grd%jnx(localRow,GlobalCol,grd%km))   ; grd%jnx  = huge(grd%jnx(1,1,1))

  ALLOCATE ( Dump_chl(grd%im,grd%jm,grd%km) ) ; Dump_chl  = 0.0
  ALLOCATE ( Dump_msk(grd%im,grd%jm) )        ; Dump_msk  = 0.0
  ALLOCATE ( grd%chl(grd%im,grd%jm,grd%km,grd%nchl) )    ; grd%chl    = huge(grd%chl(1,1,1,1))
  ALLOCATE ( grd%chl_ad(grd%im,grd%jm,grd%km,grd%nchl) ) ; grd%chl_ad = huge(grd%chl_ad(1,1,1,1))

  ALLOCATE ( x3(grd%im,grd%jm,grd%km)) ;  x3 = huge(x3(1,1,1))
  ALLOCATE ( x2(grd%im,grd%jm))        ;  x2 = huge(x2(1,1))
  ALLOCATE ( x1(grd%km) )              ;  x1 = huge(x1(1))

  if (drv%argo .eq. 1) then
     ALLOCATE ( grd%lon(grd%im,grd%jm)) ; grd%lon = huge(grd%lon(1,1))
     ALLOCATE ( grd%lat(grd%im,grd%jm)) ; grd%lat = huge(grd%lat(1,1))
  endif

  ierr = nf90mpi_inq_varid (ncid, 'dx', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart, MyCount, x2)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all dx', ierr)
  grd%dx(:,:) = x2(:,:)

  ierr = nf90mpi_inq_varid (ncid, 'dy', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart, MyCount, x2)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all dy', ierr)
  grd%dy(:,:) = x2(:,:)

  if (drv%argo .eq. 1) then
     ierr = nf90mpi_inq_varid (ncid, 'lon', VarId)
     if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
     ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart, MyCount, x2)
     if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all lon', ierr)
     grd%lon(:,:) = x2(:,:)

     ierr = nf90mpi_inq_varid (ncid, 'lat', VarId)
     if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
     ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart, MyCount, x2)
     if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all lat', ierr)
     grd%lat(:,:) = x2(:,:)
  endif


  ierr = nf90mpi_inq_varid (ncid, 'dep', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart(3), MyCount(3), x1)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all dep', ierr)
  grd%dep(:) = x1(:)

  ierr = nf90mpi_inq_varid (ncid, 'tmsk', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart, MyCount, x3)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all msk', ierr)
  grd%msk(:,:,:) = x3(:,:,:)

  ierr = nf90mpi_inq_varid (ncid, 'regs', VarId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_varid regs', ierr)
  ierr = nfmpi_get_vara_real_all (ncid, VarId, MyStart, MyCount, x2)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_get_vara_real_all regs', ierr)
  grd%reg(:,:) = int(x2(:,:))

  ierr = nf90mpi_close(ncid)

  DEALLOCATE ( x3, x2, x1 )


  ! end copy-paste from rdgrds.f90
  ! *****************************************************************************************
  ! *****************************************************************************************

end subroutine parallel_rdgrd

subroutine DomainDecomposition

  use drv_str
  use mpi_str
  use grd_str

  implicit none

  integer, allocatable :: ilcit(:,:), ilcjt(:,:), BalancedSlice(:,:)
  integer(i8) :: ji, jj, TmpInt, ierr ! jpi, jpj, nn, i
  integer(i8) :: GlobalRestCol, GlobalRestRow
  integer(i8) :: i, j, k, kk
  integer(i8) :: NCoastX, NCoastY, TmpCoast
  integer(i8) :: NRows, NCols
  integer(i8) :: SliceRestRow, SliceRestCol
  integer(i8) :: OffsetCol, OffsetRow
  real        :: TotX, TotY, C
  integer     :: nnx, ii, iProc, i0

  integer, allocatable :: ToBalanceX(:,:), ToBalanceY(:,:)

  GlobalRestRow = mod(GlobalRow, NumProcI)
  GlobalRestCol = mod(GlobalCol, NumProcJ)

  if(drv%ReadDomDec .eq. 1) then
     allocate(ilcit(NumProcI, NumProcJ))
     allocate(ilcjt(NumProcI, NumProcJ))
     allocate(BalancedSlice(NumProcI, NumProcJ))

     if(MyRank .eq. 0) then

        ! ALLOCATE(ToBalanceX(GlobalCol, grd%km))
        ! ALLOCATE(ToBalanceY(GlobalRow, grd%km))
        ! ToBalanceX(:,:) = 0
        ! ToBalanceY(:,:) = 0
        ALLOCATE(ToBalanceX(GlobalCol, grd%km))
        ALLOCATE(ToBalanceY(GlobalRow, grd%km))
        ToBalanceX(:,:) = 0
        ToBalanceY(:,:) = 0

        do k = 1, grd%km
           
           do j = 1, GlobalCol
              kk = grd%istp(1,j)
              if( grd%global_msk(1,j,k).eq.1. ) kk = kk + 1
              do i = 2, GlobalRow
                 if( grd%global_msk(i,j,k).eq.0. .and. grd%global_msk(i-1,j,k).eq.1. ) then
                    kk = kk + grd%istp(i,j)
                 else if( grd%global_msk(i,j,k).eq.1. .and. grd%global_msk(i-1,j,k).eq.0. ) then
                    kk = kk + grd%istp(i,j) + 1
                 else if( grd%global_msk(i,j,k).eq.1. ) then
                    kk = kk + 1
                 endif
              enddo
              ! ToBalanceX(j,k) = kk+grd%istp(GlobalRow,j) ! max( ToBalanceX(k), kk+grd%istp(grd%im,j))
              ! ToBalanceX(j) = ToBalanceX(j) + kk+grd%istp(GlobalRow,j) ! max( ToBalanceX(k), kk+grd%istp(grd%im,j))
              ToBalanceX(j,k) = kk+grd%istp(GlobalRow,j)
           enddo
           ! grd%imax   = max( grd%imax, ToBalanceX(k))
           
           do i = 1, GlobalRow
              kk = grd%jstp(i,1)
              if( grd%global_msk(i,1,k).eq.1. ) kk = kk + 1
              do j = 2, GlobalCol
                 if( grd%global_msk(i,j,k).eq.0. .and. grd%global_msk(i,j-1,k).eq.1. ) then
                    kk = kk + grd%jstp(i,j)
                 else if( grd%global_msk(i,j,k).eq.1. .and. grd%global_msk(i,j-1,k).eq.0. ) then
                    kk = kk + grd%jstp(i,j) + 1
                 else if( grd%global_msk(i,j,k).eq.1. ) then
                    kk = kk + 1
                 endif
              enddo
              ! ToBalanceY(i,k) = kk+grd%jstp(i,GlobalCol) !max( ToBalanceY(k), kk+grd%jstp(i,grd%jm))
              ! ToBalanceY(i) = ToBalanceY(i) + kk+grd%jstp(i,GlobalCol) !max( ToBalanceY(k), kk+grd%jstp(i,grd%jm))
              ToBalanceY(i,k) = kk+grd%jstp(i,GlobalCol)
           enddo
           ! grd%jmax   = max( grd%jmax, ToBalanceY(k))
           
        enddo
        
        NCoastX = 0
        NCoastY = 0
        do j=1,GlobalCol
           do k=1,grd%km
              NCoastX = NCoastX + ToBalanceX(j,k)
           end do
        end do
        do i=1,GlobalRow
           do k=1,grd%km
              NCoastY = NCoastY + ToBalanceY(i,k)
           end do
        end do
        
       
        print*, "Total number of X Coast Points: ", NCoastX, "Y Coast Points: ", NCoastY

        TotX = 0
        TotY = 0
        do k=1,grd%km
           TotX = TotX + MAXVAL(ToBalanceX(:,k))
           TotY = TotY + MAXVAL(ToBalanceY(:,k))
        end do

        TotX = TotX * GlobalCol / Size
        TotY = TotY * GlobalRow / Size

        TotX = TotX * 0.65
        TotY = TotY * 0.65

        i0 = 1
        do iProc=1,Size-1
           ii = i0
           C = 0
           do while(C < TotX .and. ii .lt. GlobalCol)

              C = 0
              nnx = ii-i0+1
              TmpInt = 0
              do k=1,grd%km
                 call MyMax(ToBalanceX, GlobalCol, grd%km, i0, ii, k, TmpInt)
                 C = C + TmpInt*nnx
              end do
              ii=ii+1

           end do
           print*, iProc, C, TotX, nnx
           BalancedSlice(iProc, 1) = nnx
           i0 = ii
           nnx = 0
        end do
        
        C = 0
        TmpInt = 0
        nnx = GlobalCol - ii + 1
        do k=1,grd%km
           call MyMax(ToBalanceX, GlobalCol, grd%km, ii, GlobalCol, k, TmpInt)
           C = C + TmpInt*nnx
        end do
              
        print*, Size, C, TotX, GlobalCol - ii+1

        BalancedSlice(Size, 1) = GlobalCol - ii +1

        i0 = 1
        do iProc=1,Size-1
           ii = i0
           C = 0
           do while(C < TotY .and. ii .lt. GlobalRow)

              C = 0
              nnx = ii-i0+1
              TmpInt = 0
              do k=1,grd%km
                 call MyMax(ToBalanceY, GlobalRow, grd%km, i0, ii, k, TmpInt)
                 C = C + TmpInt*nnx
              end do
              ii=ii+1

           end do

           print*, iProc, C, TotY, nnx
           ilcit(iProc, 1) = nnx
           ilcjt(iProc, 1) = GlobalCol
           i0 = ii
           
        end do

        C = 0
        TmpInt = 0
        nnx = GlobalRow - ii + 1
        do k=1,grd%km
           call MyMax(ToBalanceY, GlobalRow, grd%km, ii, GlobalRow, k, TmpInt)
           C = C + TmpInt*nnx
        end do
              
        print*, Size, C, TotY, GlobalRow - ii+1

        ilcit(Size, 1) = GlobalRow - ii +1
        ilcjt(Size, 1) = GlobalCol
        
        print*, "ilcit:", ilcit(:,:)
        print*, "ilcjt", ilcjt(:,:)
        print*, "BS:", BalancedSlice(:,:)
        ! call MPI_Abort(MPI_COMM_WORLD, -1, ierr)

        ! TmpCoast = 0
        ! TmpInt = 1
        ! NCols  = 0
        ! do j = 1, GlobalCol
        !    TmpCoast = TmpCoast + ToBalanceX(j)
        !    NCols = NCols + 1
        !    if(TmpCoast .ge. NCoastX/size .or. j .eq. GlobalCol) then
        !       print*, "Process", TmpInt-1, "has", TmpCoast, "Coast Points on X"
        !       BalancedSlice(TmpInt, 1) = NCols
        !       TmpCoast = 0
        !       NCols = 0
        !       TmpInt = TmpInt + 1
        !    endif
        ! end do

        ! TmpCoast = 0
        ! TmpInt = 1
        ! NRows  = 0
        ! do i = 1, GlobalRow
        !    TmpCoast = TmpCoast + ToBalanceY(i)
        !    NRows = NRows + 1
        !    if(TmpCoast .ge. NCoastY/size .or. i .eq. GlobalRow) then
        !       print*, "Process", TmpInt-1, "has", TmpCoast, "Coast Points on Y"
        !       ilcit(TmpInt, 1) = NRows
        !       ilcjt(TmpInt, 1) = GlobalCol
        !       TmpCoast = 0
        !       NRows = 0
        !       TmpInt = TmpInt + 1
        !    endif
        ! end do


        ! do i=2,GlobalRow
           
        !    do j=1,GlobalCol
        !       do k=1,grd%km
        !          ! if(grd%global_msk(i,j,k) .eq. 1) then
        !          ! if (grd%global_msk(i,j,k).eq.1 .and. grd%global_msk(i-1,j,k).eq.0 &
        !          ! .or. grd%global_msk(i,j,k).eq.0 .and. grd%global_msk(i-1,j,k).eq.1 &
        !          ! .or. grd%global_msk(i,j,k).eq.1) then
        !          !   TmpCoast = TmpCoast + 1
        !          ! endif
        !          if (grd%global_msk(i,j,k).eq.1 .and. grd%global_msk(i-1,j,k).eq.0) TmpCoast = TmpCoast + 1
        !          if (grd%global_msk(i,j,k).eq.0 .and. grd%global_msk(i-1,j,k).eq.1) TmpCoast = TmpCoast + 1
        !          if (grd%global_msk(i,j,k).eq.1) TmpCoast = TmpCoast + 1
        !       end do
        !    end do
          
        !    NRows = NRows + 1
        !    if(TmpCoast .ge. NCoastX/size .or. i .eq. GlobalRow) then
        !       print*, "Process", TmpInt-1, "has", TmpCoast, "Coast Points on X"
        !       ilcit(TmpInt, 1) = NRows
        !       ilcjt(TmpInt, 1) = GlobalCol
        !       TmpCoast = 0
        !       NRows = 0
        !       TmpInt = TmpInt + 1
        !    endif
        ! end do
        ! print*, ""
        ! print*, "Compute quantities for slicing along x direction"
        ! print*, ""
        
        ! TmpCoast = 0
        ! TmpInt = 1
        ! NCols = 1
        ! do j=2,GlobalCol
        !   do i=1,GlobalRow
        !      do k=1,grd%km
        !        ! if(grd%global_msk(i,j,k) .eq. 1) then
        !        ! if (grd%global_msk(i,j,k).eq.1 .and. grd%global_msk(i,j-1,k).eq.0 &
        !        ! .or. grd%global_msk(i,j,k).eq.0 .and. grd%global_msk(i,j-1,k).eq.1 &
        !        ! .or. grd%global_msk(i,j,k).eq.1) then
        !        !   TmpCoast = TmpCoast + 1
        !        ! endif
        !        if (grd%global_msk(i,j,k).eq.1 .and. grd%global_msk(i,j-1,k).eq.0) TmpCoast = TmpCoast + 1
        !        if (grd%global_msk(i,j,k).eq.0 .and. grd%global_msk(i,j-1,k).eq.1) TmpCoast = TmpCoast + 1
        !        if (grd%global_msk(i,j,k).eq.1) TmpCoast = TmpCoast + 1
        !     end do
        !   end do
        !   NCols = NCols + 1
        !   if(TmpCoast .ge. NCoastY/size .or. j .eq. GlobalCol) then
        !     print*, "Process", TmpInt-1, "has", TmpCoast, "Coast Points on Y"
        !     BalancedSlice(TmpInt, 1) = NCols
        !     TmpCoast = 0
        !     NCols = 0
        !     TmpInt = TmpInt + 1
        !   endif
        ! end do

        write(*,*) ""
        write(*,*) "ilcit:", ilcit(:,1)
        write(*,*) "BalancedSlice:", BalancedSlice(:,:)
        write(*,*) ""
        
        DEALLOCATE(ToBalanceX, ToBalanceY)

     endif
     call MPI_Bcast(ilcit, NumProcI, MPI_INT, 0, MPI_COMM_WORLD, ierr)
     call MPI_Bcast(ilcjt, NumProcI, MPI_INT, 0, MPI_COMM_WORLD, ierr)
     call MPI_Bcast(BalancedSlice, NumProcI, MPI_INT, 0, MPI_COMM_WORLD, ierr)

    !  print*, "MyRank", MyRank, ilcit(:,:), ilcjt(:,:)

    !  call MPI_Barrier(MPI_COMM_WORLD, ierr)
    !  call MPI_Abort(MPI_COMM_WORLD, -1, ierr)
    !  open(3333,file='Dom_Dec_jpi.ascii', form='formatted')
    !  open(3334,file='Dom_Dec_jpj.ascii', form='formatted')
     !
    !  read(3333,*) ((ilcit(ji,jj), jj=1,NumProcJ),ji=1,NumProcI)
    !  read(3334,*) ((ilcjt(ji,jj), jj=1,NumProcJ),ji=1,NumProcI)
     !
    !  close(3333)
    !  close(3334)
     !
    !  do ji=1,NumProcI
    !     do jj=1,NumProcJ
    !        if(NumProcJ .gt. 1) then
    !           if(mod(NumProcJ-jj, NumProcJ-1) .eq. 0) then
    !              ilcjt(ji,jj) = ilcjt(ji,jj) - 1
    !           else
    !              ilcjt(ji,jj) = ilcjt(ji,jj) - 2
    !           end if
    !        end if
    !        if(NumProcI .gt. 1) then
    !           if(mod(NumProcI-ji, NumProcI-1) .eq. 0) then
    !              ilcit(ji,jj) = ilcit(ji,jj) - 1
    !           else
    !              ilcit(ji,jj) = ilcit(ji,jj) - 2
    !           end if
    !        end if
    !     end do
    !  end do

     grd%im = ilcit(MyPosI+1, MyPosJ+1)
     grd%jm = ilcjt(MyPosI+1, MyPosJ+1)
     MyCount(1) = grd%im
     MyCount(2) = grd%jm
     MyCount(3) = grd%km

     MyStart(:) = 1

     do i=1,MyPosI
        MyStart(1) = MyStart(1) + ilcit(i,MyPosJ+1)
     end do
     do i=1,MyPosJ
        MyStart(2) = MyStart(2) + ilcjt(MyPosI+1, i)
     end do
     MyStart(3) = 1

     write(*,*) "MyRank = ", MyRank, " MyStart = ", MyStart, " MyCount = ", MyCount

     !
     ! initializing quantities needed to slicing along i and j directions
     !
     localRow = grd%im / NumProcJ
     localCol = BalancedSlice(MyPosI+1, MyPosJ+1) ! grd%jm / NumProcI
    !  SliceRestRow = mod(grd%im, NumProcJ)
    !  SliceRestCol = 0 !mod(grd%jm, NumProcI)
     !
    !  ! x direction (-> GlobalRow)
    !  if(SliceRestCol .ne. 0) then !print*,"WARNING!!!!!! mod(grd%jm, NumProcI) .ne. 0!!! Case not implemented yet!!"
    !     if(MyPosI .lt. SliceRestCol) &
    !          localCol = localCol + 1
    !  end if

     SendDisplX4D(1) = 0
     RecDisplX4D(1)  = 0

     SendDisplX2D(1) = 0
     RecDisplX2D(1)  = 0

     do i=1,NumProcI
        ! if(i-1 .lt. SliceRestCol) then
        !    OffsetRow = 1
        ! else
        !    OffsetRow = 0
        ! end if
        !
        ! if(i-1 .lt. mod(GlobalRow, NumProcI)) then
        !    OffsetCol = 1
        ! else
        !    OffsetCol = 0
        ! end if

        ! SendCountX4D(i) = (grd%jm / NumProcI + OffsetRow) * grd%im * grd%km
        ! RecCountX4D(i)  = localCol * grd%km * ilcit(i, MyPosJ+1)
        SendCountX4D(i) = BalancedSlice(i,1) * grd%im * grd%km
        RecCountX4D(i)  = localCol * grd%km * ilcit(i, MyPosJ+1)

        ! SendCountX2D(i) = (grd%jm / NumProcI + OffsetRow) * grd%im
        SendCountX2D(i) = BalancedSlice(i,1) * grd%im
        RecCountX2D(i)  = localCol * ilcit(i, MyPosJ+1)

        if(i .lt. NumProcI) then
           SendDisplX4D(i+1) = SendDisplX4D(i) + SendCountX4D(i)
           RecDisplX4D(i+1)  = RecDisplX4D(i) + RecCountX4D(i)

           SendDisplX2D(i+1) = SendDisplX2D(i) + SendCountX2D(i)
           RecDisplX2D(i+1)  = RecDisplX2D(i) + RecCountX2D(i)
        end if
     end do

     ! y direction (-> GlobalCol)
    !  if(SliceRestRow .ne. 0) then
    !     if(MyPosJ .lt. SliceRestRow) &
    !          localRow = localRow + 1
    !  end if

     SendDisplY4D(1) = 0
     RecDisplY4D(1)  = 0

     SendDisplY2D(1) = 0
     RecDisplY2D(1)  = 0

     SendCountY4D(1) = grd%im * grd%jm * grd%km
     RecCountY4D(1)  = localRow * grd%km * ilcjt(MyPosI+1, MyPosJ+1)
     SendCountY2D(1) = grd%im * grd%jm
     RecCountY2D(1)  = localRow * ilcjt(MyPosI+1, MyPosJ+1)

    !  do i=1,NumProcJ
    !     if(i-1 .lt. SliceRestRow) then
    !        OffsetCol = 1
    !     else
    !        OffsetCol = 0
    !     end if
     !
    !     if(i-1 .lt. mod(GlobalCol, NumProcJ)) then
    !        OffsetRow = 1
    !     else
    !        OffsetRow = 0
    !     end if
     !
    !     SendCountY4D(i) = (grd%im / NumProcJ + OffsetCol) * grd%jm * grd%km
    !     RecCountY4D(i)  = localRow * grd%km * ilcjt(MyPosI+1, i)
     !
    !     SendCountY2D(i) = (grd%im / NumProcJ + OffsetCol) * grd%jm
    !     RecCountY2D(i)  = localRow * ilcjt(MyPosI+1, i)
     !
    !     if(i .lt. NumProcJ) then
    !        SendDisplY4D(i+1) = SendDisplY4D(i) + SendCountY4D(i)
    !        RecDisplY4D(i+1)  = RecDisplY4D(i) + RecCountY4D(i)
     !
    !        SendDisplY2D(i+1) = SendDisplY2D(i) + SendCountY2D(i)
    !        RecDisplY2D(i+1)  = RecDisplY2D(i) + RecCountY2D(i)
    !     end if
    !  end do

     if(MyPosI .lt. GlobalRestRow) then
        TmpInt = 0
     else
        TmpInt = 1
     end if
     GlobalRowOffset = SendDisplY2D(MyPosJ+1)/grd%jm
     do i=1,MyPosI
        GlobalRowOffset = GlobalRowOffset + ilcit(i, MyPosJ+1)
     end do

     if(MyPosJ .lt. GlobalRestCol) then
        TmpInt = 0
     else
        TmpInt = 1
     end if
     GlobalColOffset = SendDisplX2D(MyPosI+1)/grd%im
     do i=1,MyPosJ
        GlobalColOffset = GlobalColOffset + ilcjt(MyPosI+1, i)
     end do

     DEALLOCATE(ilcit, ilcjt, BalancedSlice)

  else ! drv%ReadDomDec .eq. 0
     !*******************************************
     !
     ! PDICERBO version of the domain decomposition:
     ! the domain is divided among the processes into slices
     ! of size (GlobalRow / NumProcI, GlobalCol / NumProcJ).
     ! Clearly, the division is done tacking into account
     ! rests. The only condition we need is that NumProcI*NumProcJ = NPROC
     !
     ! WARNING!!! netcdf stores data in ROW MAJOR order
     ! while here we are reading in column major order.
     ! We have to take into account this simply swapping ("ideally")
     ! the entries of MyStart and MyCount
     !
     !*******************************************

     ! computing rests for X direction
     MyCount(1) = GlobalRow / NumProcI
     MyCount(2) = GlobalCol / NumProcJ

     OffsetRow = 0
     if (MyPosI .lt. GlobalRestRow) then
        MyCount(1) = MyCount(1) + 1
        OffsetRow = MyPosI
     else
        OffsetRow = GlobalRestRow
     end if

     ! computing rests for Y direction
     OffsetCol = 0
     if (MyPosJ .lt. GlobalRestCol) then
        MyCount(2) = MyCount(2) + 1
     else
        OffsetCol = GlobalRestCol
     end if

     TmpInt = GlobalRow / NumProcI
     MyStart(1) = TmpInt * MyPosI + OffsetRow + 1
     MyCount(1) = MyCount(1)

     TmpInt = MyRank / NumProcI
     MyStart(2) = mod(MyCount(2) * TmpInt + OffsetCol, GlobalCol) + 1
     MyCount(2) = MyCount(2)

     ! taking all values along k direction
     MyStart(3) = 1
     MyCount(3) = grd%km

     write(*,*) "MyRank = ", MyRank, " MyStart = ", MyStart, " MyCount = ", MyCount

     grd%im = MyCount(1)
     grd%jm = MyCount(2)

     !
     ! initializing quantities needed to slicing along i and j directions
     !
     localRow = grd%im / NumProcJ
     localCol = grd%jm / NumProcI
     SliceRestRow = mod(grd%im, NumProcJ)
     SliceRestCol = mod(grd%jm, NumProcI)

     ! x direction (-> GlobalRow)
     if(SliceRestCol .ne. 0) then
        if(MyPosI .lt. SliceRestCol) &
             localCol = localCol + 1
     end if

     SendDisplX4D(1) = 0
     RecDisplX4D(1)  = 0

     SendDisplX2D(1) = 0
     RecDisplX2D(1)  = 0

     do i=1,NumProcI
        if(i-1 .lt. SliceRestCol) then
           OffsetRow = 1
        else
           OffsetRow = 0
        end if

        if(i-1 .lt. mod(GlobalRow, NumProcI)) then
           OffsetCol = 1
        else
           OffsetCol = 0
        end if

        SendCountX4D(i) = (grd%jm / NumProcI + OffsetRow) * grd%im * grd%km
        RecCountX4D(i)  = localCol * grd%km * (GlobalRow / NumProcI + OffsetCol)

        SendCountX2D(i) = (grd%jm / NumProcI + OffsetRow) * grd%im
        RecCountX2D(i)  = localCol * (GlobalRow / NumProcI + OffsetCol)

        if(i .lt. NumProcI) then
           SendDisplX4D(i+1) = SendDisplX4D(i) + SendCountX4D(i)
           RecDisplX4D(i+1)  = RecDisplX4D(i) + RecCountX4D(i)

           SendDisplX2D(i+1) = SendDisplX2D(i) + SendCountX2D(i)
           RecDisplX2D(i+1)  = RecDisplX2D(i) + RecCountX2D(i)
        end if
     end do

     ! y direction (-> GlobalCol)
     if(SliceRestRow .ne. 0) then
        if(MyPosJ .lt. SliceRestRow) &
             localRow = localRow + 1
     end if

     SendDisplY4D(1) = 0
     RecDisplY4D(1)  = 0

     SendDisplY2D(1) = 0
     RecDisplY2D(1)  = 0

     do i=1,NumProcJ
        if(i-1 .lt. SliceRestRow) then
           OffsetCol = 1
        else
           OffsetCol = 0
        end if

        if(i-1 .lt. mod(GlobalCol, NumProcJ)) then
           OffsetRow = 1
        else
           OffsetRow = 0
        end if

        SendCountY4D(i) = (grd%im / NumProcJ + OffsetCol) * grd%jm * grd%km
        RecCountY4D(i)  = localRow * grd%km * (GlobalCol / NumProcJ + OffsetRow)

        SendCountY2D(i) = (grd%im / NumProcJ + OffsetCol) * grd%jm
        RecCountY2D(i)  = localRow * (GlobalCol / NumProcJ + OffsetRow)

        if(i .lt. NumProcJ) then
           SendDisplY4D(i+1) = SendDisplY4D(i) + SendCountY4D(i)
           RecDisplY4D(i+1)  = RecDisplY4D(i) + RecCountY4D(i)

           SendDisplY2D(i+1) = SendDisplY2D(i) + SendCountY2D(i)
           RecDisplY2D(i+1)  = RecDisplY2D(i) + RecCountY2D(i)
        end if
     end do

     if(MyPosI .lt. GlobalRestRow) then
        TmpInt = 0
     else
        TmpInt = 1
     end if
     GlobalRowOffset = SendDisplY2D(MyPosJ+1)/grd%jm + MyPosI*grd%im + TmpInt*GlobalRestRow

     if(MyPosJ .lt. GlobalRestCol) then
        TmpInt = 0
     else
        TmpInt = 1
     end if
     GlobalColOffset = SendDisplX2D(MyPosI+1)/grd%im + MyPosJ*grd%jm + TmpInt*GlobalRestCol

  end if ! drv%ReadDomDec .eq. 0

end subroutine DomainDecomposition

subroutine MyMax(arr, GlobCol, km, i0, ii, k, val)

  implicit none

  integer :: i0, ii, k, j, GlobCol, km
  integer :: arr(GlobCol,km)
  integer, intent(inout)    :: val

  do j=i0,ii
     ! print*, arr(:,:)
     val = max(val, arr(j, k))
  end do

end subroutine MyMax

subroutine MyGetDimension(ncid, name, n)
  use pnetcdf
  use mpi
  implicit none

  character name*(*)
  integer :: ncid, ierr
  integer(KIND=MPI_OFFSET_KIND) :: n
  integer dimid

  ierr = nf90mpi_inq_dimid(ncid, name, DimId)
  if (ierr .ne. NF90_NOERR ) call handle_err('nf90mpi_inq_dimid', ierr)
  ierr = nfmpi_inq_dimlen(ncid, DimId, n)
  if (ierr .ne. NF90_NOERR ) call handle_err('nfmpi_inq_dimlen', ierr)

end subroutine MyGetDimension

subroutine handle_err(err_msg, errcode)

  use mpi
  use pnetcdf

  implicit none

  character*(*), intent(in) :: err_msg
  integer,       intent(in) :: errcode

  !local variables
  integer err

  write(*,*) 'Error: ', trim(err_msg), ' ', nf90mpi_strerror(errcode)
  call MPI_Abort(MPI_COMM_WORLD, -1, err)
  return
end subroutine handle_err
