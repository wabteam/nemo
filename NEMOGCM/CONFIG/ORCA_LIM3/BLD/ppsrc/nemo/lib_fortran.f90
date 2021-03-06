

MODULE lib_fortran
   !!======================================================================
   !!                       ***  MODULE  lib_fortran  ***
   !! Fortran utilities:  includes some low levels fortran functionality
   !!======================================================================
   !! History :  3.2  !  2010-05  (M. Dunphy, R. Benshila)  Original code
   !!----------------------------------------------------------------------

   !!----------------------------------------------------------------------
   !!   glob_sum    : generic interface for global masked summation over
   !!                 the interior domain for 1 or 2 2D or 3D arrays
   !!                 it works only for T points
   !!   SIGN        : generic interface for SIGN to overwrite f95 behaviour
   !!                 of intrinsinc sign function
   !!----------------------------------------------------------------------
   USE par_oce         ! Ocean parameter
   USE dom_oce         ! ocean domain
   USE in_out_manager  ! I/O manager
   USE lib_mpp         ! distributed memory computing

   IMPLICIT NONE
   PRIVATE

   PUBLIC   glob_sum   ! used in many places
   PUBLIC   DDPDD      ! also used in closea module




   INTERFACE glob_sum
      MODULE PROCEDURE glob_sum_1d, glob_sum_2d, glob_sum_3d, &
         &             glob_sum_2d_a, glob_sum_3d_a
   END INTERFACE









   !!----------------------------------------------------------------------
   !! NEMO/OPA 3.3 , NEMO Consortium (2010)
   !! $Id: lib_fortran.F90 3604 2012-11-19 14:21:34Z rblod $
   !! Software governed by the CeCILL licence     (NEMOGCM/NEMO_CeCILL.txt)
   !!----------------------------------------------------------------------
CONTAINS


   FUNCTION glob_sum_1d( ptab, kdim )
      !!-----------------------------------------------------------------------
      !!                  ***  FUNCTION  glob_sum_1D  ***
      !!
      !! ** Purpose : perform a masked sum on the inner global domain of a 1D array
      !!-----------------------------------------------------------------------
      INTEGER :: kdim
      REAL(wp), INTENT(in), DIMENSION(kdim) ::   ptab        ! input 1D array
      REAL(wp)                              ::   glob_sum_1d ! global sum
      !!-----------------------------------------------------------------------
      !
      glob_sum_1d = SUM( ptab(:) )
      IF( lk_mpp )   CALL mpp_sum( glob_sum_1d )
      !
   END FUNCTION glob_sum_1d

   FUNCTION glob_sum_2d( ptab )
      !!-----------------------------------------------------------------------
      !!                  ***  FUNCTION  glob_sum_2D  ***
      !!
      !! ** Purpose : perform a masked sum on the inner global domain of a 2D array
      !!-----------------------------------------------------------------------
      REAL(wp), INTENT(in), DIMENSION(:,:) ::   ptab          ! input 2D array
      REAL(wp)                             ::   glob_sum_2d   ! global masked sum
      !!-----------------------------------------------------------------------
      !
      glob_sum_2d = SUM( ptab(:,:)*tmask_i(:,:) )
      IF( lk_mpp )   CALL mpp_sum( glob_sum_2d )
      !
   END FUNCTION glob_sum_2d


   FUNCTION glob_sum_3d( ptab )
      !!-----------------------------------------------------------------------
      !!                  ***  FUNCTION  glob_sum_3D  ***
      !!
      !! ** Purpose : perform a masked sum on the inner global domain of a 3D array
      !!-----------------------------------------------------------------------
      REAL(wp), INTENT(in), DIMENSION(:,:,:) ::   ptab          ! input 3D array
      REAL(wp)                               ::   glob_sum_3d   ! global masked sum
      !!
      INTEGER :: jk
      !!-----------------------------------------------------------------------
      !
      glob_sum_3d = 0.e0
      DO jk = 1, jpk
         glob_sum_3d = glob_sum_3d + SUM( ptab(:,:,jk)*tmask_i(:,:) )
      END DO
      IF( lk_mpp )   CALL mpp_sum( glob_sum_3d )
      !
   END FUNCTION glob_sum_3d


   FUNCTION glob_sum_2d_a( ptab1, ptab2 )
      !!-----------------------------------------------------------------------
      !!                  ***  FUNCTION  glob_sum_2D _a ***
      !!
      !! ** Purpose : perform a masked sum on the inner global domain of two 2D array
      !!-----------------------------------------------------------------------
      REAL(wp), INTENT(in), DIMENSION(:,:) ::   ptab1, ptab2    ! input 2D array
      REAL(wp)            , DIMENSION(2)   ::   glob_sum_2d_a   ! global masked sum
      !!-----------------------------------------------------------------------
      !
      glob_sum_2d_a(1) = SUM( ptab1(:,:)*tmask_i(:,:) )
      glob_sum_2d_a(2) = SUM( ptab2(:,:)*tmask_i(:,:) )
      IF( lk_mpp )   CALL mpp_sum( glob_sum_2d_a, 2 )
      !
   END FUNCTION glob_sum_2d_a


   FUNCTION glob_sum_3d_a( ptab1, ptab2 )
      !!-----------------------------------------------------------------------
      !!                  ***  FUNCTION  glob_sum_3D_a ***
      !!
      !! ** Purpose : perform a masked sum on the inner global domain of two 3D array
      !!-----------------------------------------------------------------------
      REAL(wp), INTENT(in), DIMENSION(:,:,:) ::   ptab1, ptab2    ! input 3D array
      REAL(wp)            , DIMENSION(2)     ::   glob_sum_3d_a   ! global masked sum
      !!
      INTEGER :: jk
      !!-----------------------------------------------------------------------
      !
      glob_sum_3d_a(:) = 0.e0
      DO jk = 1, jpk
         glob_sum_3d_a(1) = glob_sum_3d_a(1) + SUM( ptab1(:,:,jk)*tmask_i(:,:) )
         glob_sum_3d_a(2) = glob_sum_3d_a(2) + SUM( ptab2(:,:,jk)*tmask_i(:,:) )
      END DO
      IF( lk_mpp )   CALL mpp_sum( glob_sum_3d_a, 2 )
      !
   END FUNCTION glob_sum_3d_a


   SUBROUTINE DDPDD( ydda, yddb )
      !!----------------------------------------------------------------------
      !!               ***  ROUTINE DDPDD ***
      !!
      !! ** Purpose : Add a scalar element to a sum
      !!
      !!
      !! ** Method  : The code uses the compensated summation with doublet
      !!              (sum,error) emulated useing complex numbers. ydda is the
      !!               scalar to add to the summ yddb
      !!
      !! ** Action  : This does only work for MPI.
      !!
      !! References : Using Acurate Arithmetics to Improve Numerical
      !!              Reproducibility and Sability in Parallel Applications
      !!              Yun HE and Chris H. Q. DING, Journal of Supercomputing 18, 259-277, 2001
      !!----------------------------------------------------------------------
      COMPLEX(wp), INTENT(in   ) ::   ydda
      COMPLEX(wp), INTENT(inout) ::   yddb
      !
      REAL(wp) :: zerr, zt1, zt2  ! local work variables
      !!-----------------------------------------------------------------------
      !
      ! Compute ydda + yddb using Knuth's trick.
      zt1  = REAL(ydda) + REAL(yddb)
      zerr = zt1 - REAL(ydda)
      zt2  = ( (REAL(yddb) - zerr) + (REAL(ydda) - (zt1 - zerr)) )   &
         &   + AIMAG(ydda)         + AIMAG(yddb)
      !
      ! The result is t1 + t2, after normalization.
      yddb = CMPLX( zt1 + zt2, zt2 - ((zt1 + zt2) - zt1), wp )
      !
   END SUBROUTINE DDPDD


   !!======================================================================
END MODULE lib_fortran
