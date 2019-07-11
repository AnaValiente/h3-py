import h3py.hexmem as hexmem
from h3py.api._api_template import api_functions


# todo: add validation (just do it in `_in_scalar()`?)
# todo: how to write documentation once and have it carry over to each interface?

def _id(x):
    return x

def _in_collection(hexes):
    it = list(hexes)

    return from_iter(it)

def _out_collection(mv):
    return set(mv)


funcs = api_functions(
    _in_scalar = _id,
    _out_scalar = _id,
    _in_collection = _in_collection,
    _out_collection = _out_collection,
    _validate=True,
)

globals().update(funcs)

