#include <stdbool.h>
#include <stdint.h>

#include "krmllib.h"

krml_checked_int_t Prims_op_Multiply(krml_checked_int_t x, krml_checked_int_t y)
{
  return x * y;
}

krml_checked_int_t Prims_op_Subtraction(krml_checked_int_t x, krml_checked_int_t y)
{
  return x - y;
}

krml_checked_int_t Prims_op_Addition(krml_checked_int_t x, krml_checked_int_t y)
{
  return x + y;
}

bool Prims_op_LessThanOrEqual(krml_checked_int_t x0, krml_checked_int_t x1)
{
  return x0 <= x1;
}

bool Prims_op_GreaterThan(krml_checked_int_t x0, krml_checked_int_t x1)
{
  return x0 > x1;
}

bool Prims_op_GreaterThanOrEqual(krml_checked_int_t x0, krml_checked_int_t x1)
{
  return x0 >= x1;
}

bool Prims_op_LessThan(krml_checked_int_t x0, krml_checked_int_t x1)
{
  return x0 < x1;
}

krml_checked_int_t FStar_UInt32_v(uint32_t x)
{
  return x;
}

uint32_t FStar_UInt32_uint_to_t(krml_checked_int_t x)
{
  return (uint32_t)x;
}

krml_checked_int_t FStar_UInt8_v(uint8_t x)
{
  return x;
}

krml_checked_int_t FStar_UInt16_v(uint16_t x)
{
  return x;
}

uint16_t FStar_UInt16_uint_to_t(krml_checked_int_t x)
{
  return (uint16_t)x;
}
