import numpy as np

from h3py.api._api_template import api_functions


def _id(x):
    return x


funcs = api_functions(
    _in_scalar = _id,
    _out_scalar = _id,
    _in_collection = _id,
    _out_collection = np.asarray,
    _validate=False,
)

# todo: not sure if this is the best way to do this...
# if too weird, we can always fall back to just cut-and-pasting the contents
# of the `api_functions` body. However, that isn't very DRY.
# Something like a python #include macro would be nice here...
globals().update(funcs)


