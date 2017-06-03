#ifndef P4_TIME_INCLUDE_P4_
#define P4_TIME_INCLUDE_P4_

#include "core.p4"
extern Timestamp{
	bit<64> getTimeStamp();
} 
