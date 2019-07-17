from h3py.util cimport create_ptr, create_mv, GeoPolygon
cimport h3py.util as u
import h3py.util as u

from cpython cimport bool

cimport h3py.h3api as h3c
from h3py.h3api cimport H3int

# move the hex2int and int2hex things in here
# h3int error codes should be 1


# bool is a python type, so we don't need the except clause
cpdef bool is_valid(H3int h):
    """Validates an `h3_address`

    :returns: boolean
    """
    return h3c.h3IsValid(h) == 1

cpdef bool is_pentagon(H3int h):
    return h3c.h3IsPentagon(h) == 1

cpdef int base_cell(H3int h) except -1:
    # todo: `get_base_cell` a better name?
    u._v_addr(h)

    return h3c.h3GetBaseCell(h)


cpdef int resolution(H3int h) except -1:
    """Returns the resolution of an `h3_address`
    0--15
    """
    u._v_addr(h)

    return h3c.h3GetResolution(h)


cpdef H3int parent(H3int h, int res) except 1:
    # todo: have this infer the res if not specified (res(h) + 1)
    # todo: validate resolution
    u._v_addr(h)

    return h3c.h3ToParent(h, res)


cpdef int distance(H3int h1, H3int h2) except -1:
    """ compute the hex-distance between two hexagons
    """
    u._v_addr(h1)
    u._v_addr(h2)

    d = h3c.h3Distance(h1,h2)

    return d

cpdef H3int[:] k_ring(H3int h, int ring_size):
    """ Return *disk* of hex radius ring_size
    todo: rename ring_size to k?

    """
    u._v_addr(h)
    if ring_size < 0:
        raise u.H3ValueError('Invalid ring size: {}'.format(ring_size))

    n = h3c.maxKringSize(ring_size)

    ptr = create_ptr(n) # todo: return a "smart" pointer that knows its length?
    h3c.kRing(h, ring_size, ptr)
    mv = create_mv(ptr, n)

    return mv

cpdef H3int[:] hex_ring(H3int h, int ring_size):
    """
    Return *hollow* ring around h.

    """
    u._v_addr(h)

    n = 6*ring_size if ring_size > 0 else 1
    ptr = create_ptr(n)

    flag = h3c.hexRing(h, ring_size, ptr)
    mv = create_mv(ptr, n)

    # todo: maybe let something else do this...?
    # todo: we can do this much more efficiently by using kRingDistances
    if flag != 0:
        # todo: raise error here
        # do we fall back to something slower?
        # fall back to `kRingDistances` and filter for appropriate distance. don't need to use sets
        pass
        # s1 = k_ring(h, ring_size).set_int()
        # s2 = k_ring(h, ring_size - 1).set_int() # todo: actually, these are probably broken right now
        # mv = from_ints(s1-s2)

    return mv



cpdef H3int[:] children(H3int h, int res):
    u._v_addr(h)
    u._v_res(res)

    # todo: have this infer the res (res(h) - 1) if not specified
    n = h3c.maxH3ToChildrenSize(h, res)

    ptr = create_ptr(n)
    h3c.h3ToChildren(h, res, ptr)
    mv = create_mv(ptr, n)

    return mv



cpdef H3int[:] compact(const H3int[:] hu):
    for h in hu:
        u._v_addr(h)

    ptr = create_ptr(len(hu))
    flag = h3c.compact(&hu[0], ptr, len(hu))
    mv = create_mv(ptr, len(hu))

    if flag != 0:
        raise ValueError('Could not compact set of hexagons!')

    return mv

# todo: https://stackoverflow.com/questions/50684977/cython-exception-type-for-a-function-returning-a-typed-memoryview
# apparently, memoryviews are python objects, so we don't need to do the except clause
cpdef H3int[:] uncompact(const H3int[:] hc, int res):
    for h in hc:
        u._v_addr(h)

    N = h3c.maxUncompactSize(&hc[0], len(hc), res)

    ptr = create_ptr(N)
    flag = h3c.uncompact(
        &hc[0], len(hc),
           ptr, N,
        res
    )
    mv = create_mv(ptr, N)

    if flag != 0:
        raise ValueError('Could not uncompact set of hexagons!')

    return mv



# weird return type here
cpdef H3int num_hexagons(int resolution) except -1:
    return h3c.numHexagons(resolution)


cpdef double hex_area(int resolution, unit='km') except -1:
    area = h3c.hexAreaKm2(resolution)

    # todo: multiple units
    convert = {
        'km': 1.0,
    }
    area *= convert[unit]

    return area

cpdef double edge_length(int resolution, unit='km') except -1:
    length = h3c.edgeLengthKm(resolution)

    # todo: multiple units
    convert = {
        'km': 1.0,
    }
    length *= convert[unit]

    return length




cpdef bool are_neighbors(H3int h1, H3int h2):
    u._v_addr(h1)
    u._v_addr(h2)

    return h3c.h3IndexesAreNeighbors(h1, h2) == 1


cpdef H3int uni_edge(H3int origin, H3int destination) except 1:
    u._v_addr(origin)
    u._v_addr(destination)

    if h3c.h3IndexesAreNeighbors(origin, destination) != 1:
        raise u.H3ValueError('Hexes are not neighbors: {} and {}'.format(origin, destination))

    return h3c.getH3UnidirectionalEdge(origin, destination)


cpdef bool is_uni_edge(H3int e):
    u._v_edge(e)

    return h3c.h3UnidirectionalEdgeIsValid(e) == 1

cpdef H3int uni_edge_origin(H3int e) except 1:
    u._v_edge(e)

    return h3c.getOriginH3IndexFromUnidirectionalEdge(e)

cpdef H3int uni_edge_destination(H3int e) except 1:
    u._v_edge(e)

    return h3c.getDestinationH3IndexFromUnidirectionalEdge(e)

cpdef (H3int, H3int) uni_edge_hexes(H3int e) except *:
    u._v_edge(e)

    return uni_edge_origin(e), uni_edge_destination(e)

cpdef H3int[:] uni_edges_from_hex(H3int origin):
    """ Returns the 6 (or 5 for pentagons) edges associated with the hex
    """
    u._v_addr(origin)

    ptr = create_ptr(6)
    h3c.getH3UnidirectionalEdgesFromHexagon(origin, ptr)
    mv = create_mv(ptr, 6)

    return mv

#####
## geo stuff
#####


cpdef H3int geo_to_h3(double lat, double lng, int res) except 1:
    cdef:
        h3c.GeoCoord c

    u._v_res(res)

    c = u.geo2coord(lat, lng)

    return h3c.geoToH3(&c, res)


cpdef (double, double) h3_to_geo(H3int h) except *:
    """Reverse lookup an h3 address into a geo-coordinate"""
    cdef:
        h3c.GeoCoord c

    u._v_addr(h)

    h3c.h3ToGeo(h, &c)

    return u.coord2geo(c)


# todo: nogil for expensive C operation?
def polyfill(geos, int res):
    """ A quick implementation of polyfill
    I think it *should* properly free allocated memory.
    Doesn't work with GeoPolygons with holes.

    `geos` should be a list of (lat, lng) tuples.

    """
    u._v_res(res)

    gp = GeoPolygon(geos)

    n = h3c.maxPolyfillSize(&gp.gp, res)
    ptr = create_ptr(n)

    h3c.polyfill(&gp.gp, res, ptr)
    mv = create_mv(ptr, n)

    return mv


def h3_to_geo_boundary(H3int h, geo_json=False):
    """Compose an array of geo-coordinates that outlines a hexagonal cell"""
    cdef:
        h3c.GeoBoundary gb

    u._v_addr(h)

    h3c.h3ToGeoBoundary(h, &gb)

    verts = tuple(
        u.coord2geo(gb.verts[i])
        for i in range(gb.num_verts)
    )

    if geo_json:
        #lat/lng -> lng/lat and last point same as first
        verts = tuple(tuple(reversed(v)) for v in verts)
        verts += (verts[0],)

    return verts

def uni_edge_boundary(H3int edge):
    """ Returns the GeoBoundary containing the coordinates of the edge
    """
    cdef:
        h3c.GeoBoundary gb

    u._v_edge(edge)

    h3c.getH3UnidirectionalEdgeBoundary(edge, &gb)

    # todo: move this verts transform into the GeoBoundary object
    verts = tuple(
        u.coord2geo(gb.verts[i])
        for i in range(gb.num_verts)
    )

    return verts

