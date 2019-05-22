from libc cimport stdlib

from cpython cimport bool
from libc.math cimport pi

cimport h3api as h3c
from h3api cimport H3int, H3str

import numpy as np



cpdef H3int hex2int(h):  # we get typing problems if we try to type input as `H3str h`
    return int(h, 16)

cpdef H3str int2hex(H3int x):
    return hex(x)[2:]

cdef double degs_to_rads(double deg):
    """Helper degrees to radians"""
    return deg * pi / 180.0


cdef double rads_to_degs(double rad):
    """Helper radians to degrees"""
    return rad * 180.0 / pi


cdef double mercator_lat(double lat):
    """Helper coerce lat range"""
    return lat - 180 if lat > 90 else lat


cdef double mercator_lng(double lng):
    """Helper coerce lng range"""
    return lng - 360 if lng > 180 else lng


cdef h3c.GeoCoord geo2coord(double lat, double lng):
    cdef:
        h3c.GeoCoord c

    c.lat = degs_to_rads(mercator_lat(lat))
    c.lng = degs_to_rads(mercator_lng(lng))

    return c


cdef (double, double) coord2geo(h3c.GeoCoord c):
    return (
        mercator_lat(rads_to_degs(c.lat)),
        mercator_lng(rads_to_degs(c.lng))
    )



cpdef H3str geo_to_h3(double lat, double lng, int res):
    return int2hex(geo_to_h3_int(lat, lng, res))

cpdef H3int geo_to_h3_int(double lat, double lng, int res):
    cdef:
        h3c.GeoCoord c

    c = geo2coord(lat, lng)

    return h3c.geoToH3(&c, res)



cpdef (double, double) h3_to_geo(H3str h):
    """Reverse lookup an h3 address into a geo-coordinate"""
    return h3_to_geo_int(hex2int(h))

cpdef (double, double) h3_to_geo_int(H3int h):
    """Reverse lookup an h3 address into a geo-coordinate"""
    cdef:
        h3c.GeoCoord c

    h3c.h3ToGeo(h, &c)

    return coord2geo(c)



def is_valid(H3str h):
    """Validates an `h3_address`

    :returns: boolean
    """
    return is_valid_int(hex2int(h))

cpdef bool is_valid_int(H3int h):
    try:
        return h3c.h3IsValid(h) is 1
    except Exception:
        return False



def resolution(H3str h):
    """Returns the resolution of an `h3_address`

    :return: nibble (0-15)
    """
    return resolution_int(hex2int(h))

cpdef int resolution_int(H3int h):
    """Returns the resolution of an `h3_address`
    0--15
    """
    return h3c.h3GetResolution(h)



def parent(H3str h3_address, int res):
    h = hex2int(h3_address)
    h = parent_int(h, res)
    h = int2hex(h)

    return h

cpdef H3int parent_int(H3int h, int res):
    return h3c.h3ToParent(h, res)



def distance(h1, h2):
    """ compute the hex-distance between two hexagons

    todo: figure out string typing.
    had to drop typing due to errors like
    `TypeError: Argument 'h2' has incorrect type (expected str, got numpy.str_)`
    """
    d = distance_int(
            hex2int(h1),
            hex2int(h2)
        )

    return d

# todo: make a function generator to do this properly...
distance_str = distance

cpdef int distance_int(H3int h1, H3int h2):
    """ compute the hex-distance between two hexagons
    """
    d = h3c.h3Distance(h1,h2)

    return d



def h3_to_geo_boundary(H3str h, bool geo_json=False):
    return h3_to_geo_boundary_int(hex2int(h), geo_json)

def h3_to_geo_boundary_int(H3int h, bool geo_json=False):
    """Compose an array of geo-coordinates that outlines a hexagonal cell"""
    cdef:
        h3c.GeoBoundary gb

    h3c.h3ToGeoBoundary(h, &gb)

    verts = tuple(
        coord2geo(gb.verts[i])
        for i in range(gb.num_verts)
    )

    if geo_json:
        #lat/lng -> lng/lat and last point same as first
        verts = tuple(tuple(reversed(v)) for v in verts)
        verts += (verts[0],)

    return verts




cpdef HexMem k_ring_hm(H3int h, int ring_size):
    n = h3c.maxKringSize(ring_size)
    hm = HexMem(n)

    h3c.kRing(h, ring_size, hm.ptr)

    return hm

def k_ring(H3str h, int ring_size):
    hm = k_ring_hm(hex2int(h), ring_size)

    return hm.set_str()

def k_ring_int(H3int h, int ring_size):
    hm = k_ring_hm(h, ring_size)

    return hm.array_int()

def k_ring_str(H3str h, int ring_size):
    hm = k_ring_hm(hex2int(h), ring_size)

    return hm.array_str()




cpdef HexMem hex_ring_hm(H3int h, int ring_size):
    """
    Get a hexagon ring for a given hexagon.
    Returns individual rings, unlike `k_ring`.

    If a pentagon is reachable, falls back to a
    MUCH slower form based on `k_ring`.
    """
    n = 6*ring_size if ring_size > 0 else 1
    hm = HexMem(n)

    flag = h3c.hexRing(h, ring_size, hm.ptr)

    if flag != 0:
        s1 = k_ring_hm(h, ring_size).set_int()
        s2 = k_ring_hm(h, ring_size - 1).set_int()
        hm = from_ints(s1-s2)

    return hm

def hex_ring(H3str h, int ring_size):
    hm = hex_ring_hm(hex2int(h), ring_size)

    return hm.set_str()

def hex_ring_str(H3str h, int ring_size):
    hm = hex_ring_hm(hex2int(h), ring_size)

    return hm.array_str()

def hex_ring_int(H3int h, int ring_size):
    hm = hex_ring_hm(h, ring_size)

    return hm.array_int()



cpdef HexMem children_hm(H3int h, int res):
    n = h3c.maxH3ToChildrenSize(h, res)
    hm = HexMem(n)

    h3c.h3ToChildren(h, res, hm.ptr)

    return hm

def children(H3str h, int res):
    hm = children_hm(hex2int(h), res)

    return hm.set_str()

def children_str(H3str h, int res):
    hm = children_hm(hex2int(h), res)

    return hm.array_str()

def children_int(H3int h, int res):
    hm = children_hm(h, res)

    return hm.array_int()



cpdef HexMem compact_hm(const H3int[:] hu):
    hc = HexMem(len(hu))

    flag = h3c.compact(&hu[0], hc.ptr, len(hu))

    if flag != 0:
        raise ValueError('Could not compact set of hexagons!')

    return hc

# todo: nogil for expensive C operation?
def compact(hexes):
    hu = from_strs(hexes)

    hc = compact_hm(hu.memview())

    return hc.set_str()

def compact_str(hexes):
    hu = from_strs(hexes)

    hc = compact_hm(hu.memview())

    return hc.array_str()

def compact_int(const H3int[:] hu not None):
    hc = compact_hm(hu)

    return hc.array_int()


# todo: or do we want a memory view version!?

# todo: do this same thing with all the other functions
cpdef HexMem uncompact_hm(const H3int[:] hc, int res):
    N = h3c.maxUncompactSize(&hc[0], len(hc), res)
    hu = HexMem(N)

    flag = h3c.uncompact(
        &hc[0], len(hc),
        hu.ptr, len(hu),
        res
    )

    if flag != 0:
        raise ValueError('Could not uncompact set of hexagons!')

    # we need to keep the HexMem object around to keep the memory from getting freed
    return hu


def uncompact(hexes, int res):
    hc = from_strs(hexes)

    hu = uncompact_hm(hc.memview(), res)

    return hu.set_str()

def uncompact_str(hexes, int res): # can't seem to type it with `H3str[:] hc not None`
    hc = from_strs(hexes)
    # and we can't just memview right away, because the HexMem will get garbage collected...

    hu = uncompact_hm(hc.memview(), res)

    return hu.array_str()

def uncompact_int(const H3int[:] hc not None, int res):
    hu = uncompact_hm(hc, res)

    return hu.array_int()


cdef h3c.Geofence make_geofence(geos):
    cdef:
        h3c.Geofence gf

    gf.numVerts = len(geos)

    # todo: figure out when/how to free this memory
    gf.verts = <h3c.GeoCoord*> stdlib.calloc(gf.numVerts, sizeof(h3c.GeoCoord))

    for i, (lat, lng) in enumerate(geos):
        gf.verts[i] = geo2coord(lat, lng)

    return gf


cdef class GeoPolygon:
    """ Basic version of GeoPolygon

    Doesn't work with holes.
    """
    cdef:
        h3c.GeoPolygon gp

    def __cinit__(self, geos):
        self.gp.numHoles = 0
        self.gp.holes = NULL
        self.gp.geofence = make_geofence(geos)

    def __dealloc__(self):
        if self.gp.geofence.verts:
            stdlib.free(self.gp.geofence.verts)


# todo: nogil for expensive C operation?
def polyfill(geos, int res):
    """ A quick implementation of polyfill
    I think it *should* properly free allocated memory.
    Doesn't work with GeoPolygons with holes.

    `geos` should be a list of (lat, lng) tuples.

    """
    gp = GeoPolygon(geos)

    n = h3c.maxPolyfillSize(&gp.gp, res)
    hm = HexMem(n)

    h3c.polyfill(&gp.gp, res, hm.ptr)

    return hm.set_str()


cdef class HexMem:
    """ A small class to manage memory for H3Index arrays
    Memory is allocated and deallocated at object creation and garbage collection
    """
    cdef:
        unsigned int n
        H3int* ptr

    def __cinit__(self, n):
        self.n = n
        self.ptr = <H3int*> stdlib.calloc(n, sizeof(H3int))

        if not self.ptr:
            raise MemoryError()

    def __dealloc__(self):
        if self.ptr:
            stdlib.free(self.ptr)

    def __len__(self):
        return self.n

    cdef void resize(self, int n):
        cdef:
            H3int* a = NULL

        self.n = n
        a = <H3int*> stdlib.realloc(self.ptr, n*sizeof(H3int))

        if a is NULL:
            stdlib.free(self.ptr)
            raise MemoryError()
        else:
            self.ptr = a


    cpdef void drop_zeros(self):
        """ Move nonzero elements to front of array.
        Does not preserve order of nonzero elements.

        Tail of array will still have nonzero elements,
        but we don't care, because we will realloc the array
        to free that memory.

        Modify self.ptr and self.n **in place**.
        """
        n = move_nonzeros(self.ptr, self.n)
        self.resize(n)

    def array_int(self):
        """ currently, this method copies. ideally, we'd re-use the memory
        and make sure it doens't get freed when HexMem gets garbage collected
        """

        # np.asarray does not copy, but there's no way to give it ownership of the memory...
        # np.array allocates new memory
        return np.array(self.memview())

    def array_str(self):
        return np.array([int2hex(h) for h in self.memview()])

    def set_str(self):
        return set(int2hex(h) for h in self.memview())

    def set_int(self):
        return set(self.memview())

    cpdef H3int[:] memview(self):
        self.drop_zeros() # how to make sure we always run this when appropriate?
        # ideally, it would just run right after the pointer is **exposed**, not
        # when we are looking to get the data.

        if self.n > 0:
            return <H3int[:self.n]> self.ptr
        else:
            return empty_memory_view()

cdef int move_nonzeros(H3int* a, int n):
    """ Move nonzero elements to front of array `a` of length `n`.

    Return the number of nonzero elements.
    """
    cdef:
        int i = 0
        int j = n

    while i < j:
        if a[j-1] == 0:
            j -= 1
            continue

        if a[i] != 0:
            i += 1
            continue

        # if we're here, we know:
        # a[i] == 0
        # a[j-1] != 0
        # i < j
        # so we can swap!
        # todo: what about j vs j-1 ....?
        a[i] = a[j-1]
        j -= 1

    return i

cpdef HexMem from_ints(hexes):
    hm = HexMem(len(hexes))

    for i, h in enumerate(hexes):
        hm.ptr[i] = h

    return hm

# maybe drop the cpdef???
cpdef HexMem from_strs(hexes):
    hm = HexMem(len(hexes))

    for i, h in enumerate(hexes):
        hm.ptr[i] = hex2int(h)

    return hm

cdef inline H3int[:] empty_memory_view():
    # there's gotta be a better way to do this...
    cdef:
        H3int a[1]

    return (<H3int[:]>a)[:0]
