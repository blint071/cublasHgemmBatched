#include <stdio.h>
#include <iostream>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <assert.h>
#include <cuda_fp16.h>

#define ROWM 1
#define COLM 100
#define COLN 100

#define cudaCheckErrors(msg) \
    do { \
        cudaError_t __err = cudaGetLastError(); \
        if (__err != cudaSuccess) { \
            fprintf(stderr, "Fatal error: %s (%s at %s:%d)\n", \
                msg, cudaGetErrorString(__err), \
                __FILE__, __LINE__); \
            fprintf(stderr, "*** FAILED - ABORTING\n"); \
            exit(1); \
        } \
    } while (0)



typedef __half mytype;
// Pi = Mi x Ni
// pr = ROWM
// pc = COLN
// mc = COLM

void GPU_Multi(mytype **M, mytype **N, mytype **P
  , size_t pr, size_t pc, size_t mc
  , size_t num_mat, mytype alpha, mytype beta)
{
    #define NUM_MAT  10000
    mytype *devM[num_mat];
    mytype *devN[num_mat];
    mytype *devP[num_mat];
    size_t p_size =sizeof(mytype) *pr*pc;
    size_t m_size =sizeof(mytype) *pr*mc;
    size_t n_size =sizeof(mytype) *mc*pc;
    const mytype **d_Marray, **d_Narray;
    mytype **d_Parray;
    cublasHandle_t myhandle;
    cublasStatus_t cublas_result;
 

 
    for(int i = 0 ; i < num_mat; i ++ )
    {
        cudaMalloc((void**)&devM[ i ], m_size );
        cudaMalloc((void**)&devN[ i ], n_size );
        cudaMalloc((void**)&devP[ i ], p_size );
    }
    cudaMalloc((void**)&d_Marray, num_mat*sizeof(mytype *));
    cudaMalloc((void**)&d_Narray, num_mat*sizeof(mytype *));
    cudaMalloc((void**)&d_Parray, num_mat*sizeof(mytype *));
    cudaCheckErrors("cudaMalloc fail");
    for(int i = 0 ; i < num_mat; i ++ ) {

        cudaMemcpy(devM[i], M[i], m_size , cudaMemcpyHostToDevice);
        cudaMemcpy(devN[i], N[i], n_size , cudaMemcpyHostToDevice);
        cudaMemcpy(devP[i], P[i], p_size , cudaMemcpyHostToDevice);
    }
    cudaMemcpy(d_Marray, devM, num_mat*sizeof(mytype *), cudaMemcpyHostToDevice);
    cudaMemcpy(d_Narray, devN, num_mat*sizeof(mytype *), cudaMemcpyHostToDevice);
    cudaMemcpy(d_Parray, devP, num_mat*sizeof(mytype *), cudaMemcpyHostToDevice);
    cudaCheckErrors("cudaMemcpy H2D fail");
    cublas_result = cublasCreate(&myhandle);
    assert(cublas_result == CUBLAS_STATUS_SUCCESS);
    // change to    cublasDgemmBatched for double
    for (int i=0 ; i<50000 ; i++)
    {  
     cublas_result = cublasHgemmBatched(myhandle, CUBLAS_OP_N, CUBLAS_OP_N
      , pr, pc, mc
      , &alpha, d_Marray, pr, d_Narray, mc
      , &beta, d_Parray, pr
      , num_mat);
    }
 
    //std::cout<<cudaElapsedTime<<std::endl;
    assert(cublas_result == CUBLAS_STATUS_SUCCESS);
    

    for(int i = 0 ; i < num_mat ; i ++ )
    {
        cudaMemcpy(P[i], devP[i], p_size, cudaMemcpyDeviceToHost);
        cudaFree(devM[i]);
        cudaFree(devN[i]);
        cudaFree(devP[i]);
    }
    cudaFree(d_Marray);
    cudaFree(d_Narray);
    cudaFree(d_Parray);
    cudaCheckErrors("cudaMemcpy D2H fail");


}

int main(){
  mytype h_M1[ROWM][COLM], h_M2[ROWM][COLM];
  mytype h_N1[COLM][COLN], h_N2[COLM][COLN];
  mytype h_P1[ROWM][COLN], h_P2[ROWM][COLN];
  mytype *h_Marray[10000], *h_Narray[10000], *h_Parray[10000];
  for (int i = 0; i < ROWM; i++)
    for (int j = 0; j < COLM; j++){
      h_M1[i][j] = 1.0f; h_M2[i][j] = 2.0f;}
  for (int i = 0; i < COLM; i++)
    for (int j = 0; j < COLN; j++){
      h_N1[i][j] = 1.0f; h_N2[i][j] = 1.0f;}
  for (int i = 0; i < ROWM; i++)
    for (int j = 0; j < COLN; j++){
      h_P1[i][j] = 0.0f; h_P2[i][j] = 0.0f;}

  for (int i = 0; i < 10000; i+=2)
  {
   h_Marray[0+i] = &(h_M1[0][0]);
   h_Marray[1+i] = &(h_M2[0][0]);
   h_Narray[0+i] = &(h_N1[0][0]);
   h_Narray[1+i] = &(h_N2[0][0]);
   h_Parray[0+i] = &(h_P1[0][0]);
   h_Parray[1+i] = &(h_P2[0][0]);
  }

  GPU_Multi(h_Marray, h_Narray, h_Parray, ROWM, COLN, COLM, 10000, 1.0f, 1.0f);

  printf("Success!\n");
  return 0;
}
