/*

Include this file in mini-rv32ima.h:
#include "definitions.h"

Then run the following command to generate a preprocessed header file:

gcc -E -P mini-rv32ima.h > standalone-mini-rv32ima.h

zig translate-c standalone-mini-rv32ima.h > rv32ima.zig
*/

typedef char int8_t;
typedef short int16_t;
typedef int int32_t;
typedef long int64_t;

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long uint64_t;

int INT32_MIN = (-2147483647-1);
int RAM_SIZE = 2*1024*1024;

int RAM_IMAGE_OFFSET = 0x80000000;

inline int mmio_range(int n) { return (0x10000000 <= (n) && (n) < 0x12000000); }
inline void store_1_byte( uint32_t ofs, uint32_t val, uint8_t* image ) { *(uint8_t*)(image + ofs) = val; }
inline void store_2_bytes( uint32_t ofs, uint32_t val, uint8_t* image ) { *(uint16_t*)(image + ofs) = val; }
inline void store_4_bytes( uint32_t ofs, uint32_t val, uint8_t* image ) { *(uint32_t*)(image + ofs) = val; }
inline uint32_t load_1_byte( uint32_t ofs, uint8_t* image ) { return *(uint8_t*)(image + ofs); }
inline uint32_t load_2_bytes( uint32_t ofs, uint8_t* image ) { return *(uint16_t*)(image + ofs); }
inline uint32_t load_4_bytes( uint32_t ofs, uint8_t* image ) { return *(uint32_t*)(image + ofs); }
inline uint32_t load_1_signed_byte( uint32_t ofs, uint8_t* image ) { return *(int8_t*)(image + ofs); }
inline uint32_t load_2_signed_bytes( uint32_t ofs, uint8_t* image ) { return *(int16_t*)(image + ofs); }

void handle_post_exec( uint32_t pc, uint32_t ir, uint32_t retval );
static uint32_t handle_control_store( uint32_t addy, uint32_t val );
static uint32_t handle_control_load( uint32_t addy );
static void handle_other_csr_write( uint8_t * image, uint16_t csrno, uint32_t value );
static int32_t handle_other_csr_read( uint8_t * image, uint16_t csrno );

#define MINIRV32_STORE4( ofs, val ) store_4_bytes(ofs, val, image)
#define MINIRV32_STORE2( ofs, val ) store_2_bytes(ofs, val, image)
#define MINIRV32_STORE1( ofs, val ) store_1_byte(ofs, val, image)
#define MINIRV32_LOAD4( ofs ) load_4_bytes(ofs, image)
#define MINIRV32_LOAD2( ofs ) load_2_bytes(ofs, image)
#define MINIRV32_LOAD1( ofs ) load_1_byte(ofs, image)
#define MINIRV32_LOAD2_SIGNED( ofs ) load_2_signed_bytes(ofs, image)
#define MINIRV32_LOAD1_SIGNED( ofs ) load_1_signed_byte(ofs, image)
#define MINIRV32_CUSTOM_MEMORY_BUS

#define MINIRV32_POSTEXEC( pc, ir, retval ) handle_post_exec( pc, ir, retval );
#define MINIRV32_HANDLE_MEM_STORE_CONTROL( addy, val ) if( handle_control_store( addy, val ) ) return val;
#define MINIRV32_HANDLE_MEM_LOAD_CONTROL( addy, rval ) rval = handle_control_load( addy );
#define MINIRV32_OTHERCSR_WRITE( csrno, value ) handle_other_csr_write( image, csrno, value );
#define MINIRV32_OTHERCSR_READ( csrno, value ) value = handle_other_csr_read( image, csrno );

#define MINIRV32_RAM_IMAGE_OFFSET RAM_IMAGE_OFFSET
#define MINIRV32_MMIO_RANGE(n) mmio_range(n)
#define MINI_RV32_RAM_SIZE RAM_SIZE
#define MINIRV32_IMPLEMENTATION