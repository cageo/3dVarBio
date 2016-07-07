subroutine tao_minimizer
  
  use drv_str
  use ctl_str
  
  implicit none
  
#include "tao_minimizer.h"
  
  PetscErrorCode  ::   ierr
  Tao             ::   tao
  Vec             ::   MyState ! array that stores the (temporary) state
  PetscInt        ::   n, M
  integer         ::   size, rank, j
  
  ! Working arrays
  PetscInt, allocatable, dimension(:)     :: loc
  PetscScalar, allocatable, dimension(:)  :: MyValues
  PetscScalar, pointer                    :: xtmp(:)
  
  external MyFuncAndGradient
  
  print*,'Initialize Petsc and Tao stuffs'  
  call PetscInitialize(PETSC_NULL_CHARACTER,ierr)
  
  call MPI_Comm_size(MPI_COMM_WORLD, size, ierr)
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  
  ! Allocate working arrays
  n = ctl%n
  M = ctl%n
  ALLOCATE(loc(n), MyValues(n))
  
  ! Take values from ctl%x_c in order to initialize the solution array
  do j = 1, ctl%n
     loc(j) = j-1
     MyValues(j) = ctl%x_c(j)
  end do
  
  call VecCreateMPI(MPI_COMM_WORLD, n, M, MyState, ierr)
  
  call VecSetValues(MyState, ctl%n, loc, MyValues, INSERT_VALUES, ierr)
  call VecAssemblyBegin(MyState, ierr)
  call VecAssemblyEnd(MyState, ierr)
  
  print*, 'PetscInitialize() done by rank ', rank

  write(drv%dia,*) ''
  write(drv%dia,*) "Within tao_minimizer subroutine!"

  drv%MyCounter = 0
  
  call TaoCreate(MPI_COMM_WORLD, tao, ierr)
  CHKERRQ(ierr)
  call TaoSetType(tao,"blmvm",ierr)
  CHKERRQ(ierr)
  
  ! Set initial solution array and MyFuncAndGradient routines
  call TaoSetInitialVector(tao, MyState, ierr)
  CHKERRQ(ierr)
  call TaoSetObjectiveAndGradientRoutine(tao, MyFuncAndGradient, PETSC_NULL_OBJECT, ierr)
  CHKERRQ(ierr)
  
  ! Perform minimization
  call TaoSolve(tao, ierr)
  CHKERRQ(ierr)
  
  ! Take computed solution and set in proper array
  call TaoGetSolutionVector(tao, MyState, ierr)
  CHKERRQ(ierr)
  call VecGetArrayReadF90(MyState, xtmp, ierr)
  CHKERRQ(ierr)

  do j = 1, ctl%n
     ctl%x_c(j) = xtmp(j)
  end do

  ! Deallocating variables
  DEALLOCATE(loc, MyValues)
  
  call TaoDestroy(tao, ierr)
  CHKERRQ(ierr)

  call VecDestroy(MyState, ierr)
  CHKERRQ(ierr)

  call PetscFinalize(ierr)
  write(drv%dia,*) 'Minimization done with ', drv%MyCounter
  write(drv%dia,*) 'iterations'
  write(drv%dia,*) ''
  
  print*, "Minimization done with ", drv%MyCounter
  print*, "iterations"

end subroutine tao_minimizer

subroutine MyFuncAndGradient(tao, MyState, CostFunc, Grad, dummy, ierr)
  
  use set_knd
  use drv_str
  use obs_str
  use grd_str
  use eof_str
  use ctl_str
  
  implicit none
  
#include "tao_minimizer.h"
  Tao             ::   tao
  Vec             ::   MyState, Grad
  PetscReal       ::   CostFunc
  integer         ::   dummy, ierr, j

  ! Working arrays
  PetscInt, allocatable, dimension(:)     :: loc
  PetscScalar, allocatable, dimension(:)  :: my_grad
  PetscScalar, pointer                    :: xtmp(:)

  ALLOCATE(loc(ctl%n), my_grad(ctl%n))

  ! read temporary state provided by Tao Solver
  ! and set it in ctl%x_c array in order to compute 
  ! the actual value of Cost Function and the gradient
  call VecGetArrayReadF90(MyState, xtmp, ierr)
  CHKERRQ(ierr)

  do j=1,ctl%n
     ctl%x_c(j) = xtmp(j)
  end do

  ! compute function and gradient
  call costf

  ! assign the Cost Function value computed by costf to CostFunc
  CostFunc = ctl%f_c

  ! assign the gradient value computed by costf to Grad
  do j = 1, ctl%n
     loc(j) = j-1
     my_grad(j) = ctl%g_c(j)
  end do

  call VecSetValues(Grad, ctl%n, loc, my_grad, INSERT_VALUES, ierr)
  CHKERRQ(ierr)
  call VecAssemblyBegin(Grad, ierr)
  CHKERRQ(ierr)
  call VecAssemblyEnd(Grad, ierr)
  CHKERRQ(ierr)

  DEALLOCATE(loc, my_grad)

  ! Update counter
  drv%MyCounter = drv%MyCounter + 1

  ! Exit without errors
  ierr = 0

end subroutine MyFuncAndGradient
