import numpy as np
cimport numpy as np
cimport cython
from libc.math cimport sin, cos, atan2, sqrt, floor, ceil, round, exp, fabs
import sys

cdef double pi = np.pi
cdef double nan = np.nan

cdef extern from "math.h":
    int isnan(double x) nogil

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef void svd2x2_decompose(double[:,:] M, double[:,:] U, double[:] s, double[:,:] V) nogil:
    cdef double E = (M[0,0] + M[1,1]) / 2
    cdef double F = (M[0,0] - M[1,1]) / 2
    cdef double G = (M[1,0] + M[0,1]) / 2
    cdef double H = (M[1,0] - M[0,1]) / 2
    cdef double Q = sqrt(E*E + H*H)
    cdef double R = sqrt(F*F + G*G)
    s[0] = Q + R
    s[1] = Q - R
    cdef double a1 = atan2(G,F)
    cdef double a2 = atan2(H,E)
    cdef double theta = (a2 - a1) / 2
    cdef double phi = (a2 + a1) / 2
    U[0,0] = cos(phi)
    U[0,1] = -sin(phi)
    U[1,0] = sin(phi)
    U[1,1] = cos(phi)
    V[0,0] = cos(theta)
    V[0,1] = sin(theta)
    V[1,0] = -sin(theta)
    V[1,1] = cos(theta)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef void mul2x2(double[:,:] A, double[:,:] B, double[:,:] C) nogil:
    C[0,0] = A[0,0] * B[0,0] + A[0,1] * B[1,0]
    C[0,1] = A[0,0] * B[0,1] + A[0,1] * B[1,1]
    C[1,0] = A[1,0] * B[0,0] + A[1,1] * B[1,0]
    C[1,1] = A[1,0] * B[0,1] + A[1,1] * B[1,1]

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double det2x2(double[:,:] M) nogil:
    return M[0,0]*M[1,1] - M[0,1]*M[1,0]

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef void svd2x2_compose(double[:,:] U, double[:] s, double[:,:] V, double[:,:] M) nogil:
    cdef double tmp00, tmp01, tmp10, tmp11
    tmp00 = U[0,0] * s[0]
    tmp01 = U[0,1] * s[1]
    tmp10 = U[1,0] * s[0]
    tmp11 = U[1,1] * s[1]
    # Multiply with transpose of V
    M[0,0] = tmp00 * V[0,0] + tmp01 * V[0,1]
    M[0,1] = tmp00 * V[1,0] + tmp01 * V[1,1]
    M[1,0] = tmp10 * V[0,0] + tmp11 * V[0,1]
    M[1,1] = tmp10 * V[1,0] + tmp11 * V[1,1]

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double hanning_filter(double x, double y) nogil:
    return (cos(min(x, 1.0)*pi)+1.0) * (cos(min(y, 1.0)*pi)+1.0) / 2.0

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double gaussian_filter(double x, double y) nogil:
    return exp(-(x*x+y*y) * 1.386294)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double clip(double x, double vmin, double vmax, int cyclic, int out_of_range_nan) nogil:
    if x < vmin:
        if cyclic:
            while x < vmin:
                x += (vmax-vmin)+1
        elif out_of_range_nan:
            return nan
        else:
            return vmin
    elif x > vmax:
        if cyclic:
            while x > vmax:
                x -= (vmax-vmin)+1
        elif out_of_range_nan:
            return nan
        else:
            return vmax
    else:
        return x

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double bilinear_interpolation(double[:,:] source, double x, double y, int x_cyclic, int y_cyclic, int out_of_range_nan) nogil:
    x = clip(x, 0, source.shape[1]-1, x_cyclic, out_of_range_nan)
    y = clip(y, 0, source.shape[0]-1, y_cyclic, out_of_range_nan)
    if isnan(x) or isnan(y):
        return nan
    cdef double floored_x = clip(floor(x), 0, source.shape[1]-1, x_cyclic, out_of_range_nan)
    cdef double floored_y = clip(floor(y), 0, source.shape[0]-1, y_cyclic, out_of_range_nan)
    cdef double ceiled_x = clip(ceil(x), 0, source.shape[1]-1, x_cyclic, out_of_range_nan)
    cdef double ceiled_y = clip(ceil(y), 0, source.shape[0]-1, y_cyclic, out_of_range_nan)
    if isnan(floored_x) or isnan(floored_y) or isnan(ceiled_x) or isnan(ceiled_y):
        return nan
    cdef double Q11_x = floored_x
    cdef double Q11_y = floored_y
    cdef double Q21_x = ceiled_x
    cdef double Q21_y = floored_y
    cdef double Q12_x = floored_x
    cdef double Q12_y = ceiled_y
    cdef double Q22_x = ceiled_x
    cdef double Q22_y = ceiled_y
    cdef double fQ11 = source[<int>Q11_y,<int>Q11_x]
    cdef double fQ21 = source[<int>Q21_y,<int>Q21_x]
    cdef double fQ12 = source[<int>Q12_y,<int>Q12_x]
    cdef double fQ22 = source[<int>Q22_y,<int>Q22_x]
    return (fQ11 * (ceiled_x - x) * (ceiled_y - y) + fQ21 * (x - floored_x) * (ceiled_y - y) + fQ12 * (ceiled_x - x) * (y - floored_y) + fQ22 * (x - floored_x) * (y - floored_y)) * ((ceiled_x - floored_x) * (ceiled_y - floored_y))

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
cdef double nearest_neighbour_interpolation(double[:,:] source, double x, double y, int x_cyclic, int y_cyclic, int out_of_range_nan) nogil:
    y = clip(round(y), 0, source.shape[0]-1, y_cyclic, out_of_range_nan)
    x = clip(round(x), 0, source.shape[1]-1, x_cyclic, out_of_range_nan)
    if isnan(y) or isnan(x):
        return nan
    return source[<int>y, <int>x]

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
def map_coordinates_direct(double[:,:] source, double[:,:] target, Ci, int x_cyclic=False, int y_cyclic=False, int out_of_range_nan=False):
    cdef np.ndarray[np.float64_t, ndim=3] pixel_target = np.zeros((target.shape[0], target.shape[1], 2))
    cdef int yi, xi
    for yi in range(target.shape[0]):
        for xi in range(target.shape[1]):
            pixel_target[yi,xi,0] = xi
            pixel_target[yi,xi,1] = yi

    cdef np.ndarray[np.float64_t, ndim=3] pixel_source = Ci(pixel_target)

    with nogil:
        for yi in range(pixel_target.shape[0]):
            for xi in range(pixel_target.shape[1]):
                if isnan(pixel_source[yi,xi,0]) or isnan(pixel_source[yi,xi,1]):
                    target[yi,xi] = nan
                    continue
                target[yi,xi] = nearest_neighbour_interpolation(source, pixel_source[yi,xi,0], pixel_source[yi,xi,1], x_cyclic, y_cyclic, out_of_range_nan)

@cython.boundscheck(False)
@cython.wraparound(False)
@cython.nonecheck(False)
@cython.cdivision(True)
def map_coordinates(double[:,:] source, double[:,:] target, Ci, int max_samples_width=-1, int conserve_flux=False, int progress=False, int singularities_nan=False, int x_cyclic=False, int y_cyclic=False, int out_of_range_nan=False):
    cdef np.ndarray[np.float64_t, ndim=3] pixel_target = np.zeros((target.shape[0], target.shape[1], 2))
    # Offset in x direction
    cdef np.ndarray[np.float64_t, ndim=3] offset_target_x = np.zeros((target.shape[0], target.shape[1]+1, 2))
    # Offset in y direction
    cdef np.ndarray[np.float64_t, ndim=3] offset_target_y = np.zeros((target.shape[0]+1, target.shape[1], 2))
    cdef int yi, xi, yoff, xoff
    for yi in range(target.shape[0]):
        for xi in range(target.shape[1]):
            pixel_target[yi,xi,0] = xi
            pixel_target[yi,xi,1] = yi
            offset_target_x[yi,xi,0] = xi - 0.5
            offset_target_x[yi,xi,1] = yi
            offset_target_y[yi,xi,0] = xi
            offset_target_y[yi,xi,1] = yi - 0.5
        offset_target_x[yi,target.shape[1],0] = target.shape[1]-1 + 0.5
        offset_target_x[yi,target.shape[1],1] = yi
    for xi in range(target.shape[1]):
        offset_target_y[target.shape[0],xi,0] = xi
        offset_target_y[target.shape[0],xi,1] = target.shape[0]-1 + 0.5

    cdef np.ndarray[np.float64_t, ndim=3] offset_source_x = Ci(offset_target_x)
    cdef np.ndarray[np.float64_t, ndim=3] offset_source_y = Ci(offset_target_y)
    cdef np.ndarray[np.float64_t, ndim=3] pixel_source = Ci(pixel_target)

    cdef double[:,:] Ji = np.zeros((2, 2))
    cdef double[:,:] J = np.zeros((2, 2))
    cdef double[:,:] U = np.zeros((2, 2))
    cdef double[:] s = np.zeros((2,))
    cdef double[:] s_padded = np.zeros((2,))
    cdef double[:] si = np.zeros((2,))
    cdef double[:,:] V = np.zeros((2, 2))
    cdef int samples_width
    cdef double[:] transformed = np.zeros((2,))
    cdef double[:] current_pixel_source = np.zeros((2,))
    cdef double[:] current_offset = np.zeros((2,))
    cdef double weight_sum = 0.0
    cdef double weight
    with nogil:
        for yi in range(pixel_target.shape[0]):
            for xi in range(pixel_target.shape[1]):
                Ji[0,0] = offset_source_x[yi,xi,0] - offset_source_x[yi,xi+1,0]
                Ji[0,1] = offset_source_x[yi,xi,1] - offset_source_x[yi,xi+1,1]
                Ji[1,0] = offset_source_y[yi,xi,0] - offset_source_y[yi+1,xi,0]
                Ji[1,1] = offset_source_y[yi,xi,1] - offset_source_y[yi+1,xi,1]
                if isnan(Ji[0,0]) or isnan(Ji[0,1]) or isnan(Ji[1,0]) or isnan(Ji[1,1]) or isnan(pixel_source[yi,xi,0]) or isnan(pixel_source[yi,xi,1]):
                    target[yi,xi] = nan
                    continue

                svd2x2_decompose(Ji, U, s, V)
                s_padded[0] = max(1.0, s[0])
                s_padded[1] = max(1.0, s[1])
                si[0] = 1.0/s[0]
                si[1] = 1.0/s[1]
                svd2x2_compose(V, si, U, J)

                target[yi,xi] = 0.0
                weight_sum = 0.0
                
                samples_width = <int>(4*ceil(max(s_padded[0], s_padded[1])))
                if max_samples_width > 0 and samples_width > max_samples_width:
                    if singularities_nan:
                        target[yi,xi] = nan
                    else:
                        target[yi,xi] = nearest_neighbour_interpolation(source, pixel_source[yi,xi,0], pixel_source[yi,xi,1], x_cyclic, y_cyclic, out_of_range_nan)
                    continue
                for yoff in range(-samples_width/2, samples_width/2, 1):
                    current_offset[1] = yoff
                    current_pixel_source[1] = round(pixel_source[yi,xi,1] + yoff)
                    for xoff in range(-samples_width/2, samples_width/2, 1):
                        current_offset[0] = xoff
                        current_pixel_source[0] = round(pixel_source[yi,xi,0] + xoff)
                        transformed[0] = J[0,0] * current_offset[0] + J[0,1] * current_offset[1]
                        transformed[1] = J[1,0] * current_offset[0] + J[1,1] * current_offset[1]
                        weight = hanning_filter(transformed[0], transformed[1])
                        weight_sum += weight
                        target[yi,xi] += weight * nearest_neighbour_interpolation(source, current_pixel_source[0], current_pixel_source[1], x_cyclic, y_cyclic, out_of_range_nan)
                target[yi,xi] /= weight_sum
                if conserve_flux:
                    target[yi,xi] *= fabs(det2x2(Ji))
            if progress:
                with gil:
                    sys.stdout.write("\r%d/%d done" % (yi+1, pixel_target.shape[0]))
                    sys.stdout.flush()
    if progress:                
        sys.stdout.write("\n")
