#include <core.p4>

header_type ipv4_t {
    fields {
        version : 4;
        ihl : 4;
        diffserv : 8;
        totalLen : 16;
        identification : 16;
        flags : 3;
        fragOffset : 13;
        ttl : 8;
        protocol : 8;
        hdrChecksum : 16;
        srcAddr : 32;
        dstAddr: 32;
        data: 32; // get the 32 bit for testing
    }
}

counter ingress_addr_count {
     type : packets;
     instance_count: 16384;
}

action set_addr_count(idx,smac,data) {
     count(ingress_addr_count, idx);//use the counter to count
     modify_field(ethernet.srcAddr, smac);//modify the source mac in the packet header
     modify_field(ipv4.data,data);//modify the header data
}
