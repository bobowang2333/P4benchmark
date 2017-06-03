#define ETHERTYPE_IPV4 0x0800
#define ETHERTYPE_PTP 0x088F7

#define TCP_PROTOCOL 0x06
#define UDP_PROTOCOL 0x11
#define GENERIC_PROTOCOL 0x9091
header_type ethernet_t {
    fields {
        dstAddr : 48;
        srcAddr : 48;
        etherType : 16;
    }
}
header_type ptp_t {
    fields {
        transportSpecific : 4;
        messageType       : 4;
        reserved          : 4;
        versionPTP        : 4;
        messageLength     : 16;
        domainNumber      : 8;
        reserved2         : 8;
        flags             : 16;
        correction        : 64;
        reserved3         : 32;
        sourcePortIdentity: 80;
        sequenceId        : 16;
        PTPcontrol        : 8;
        logMessagePeriod  : 8;
        originTimestamp   : 80;
    }
}
parser start { return parse_ethernet; }
header ethernet_t ethernet;

parser parse_ethernet {
    extract(ethernet);
    return select(latest.etherType) {
	ETHERTYPE_PTP: parse_ptp;
	default : ingress;

    }
}
header ptp_t ptp;

parser parse_ptp {
    extract(ptp);
    return select(latest.reserved2) {
	1       : parse_header_0;
	default : ingress;

    }
}
header_type header_0_t {
    fields {
		field_0 : 16;

    }
}
header header_0_t header_0;

parser parse_header_0 {
    extract(header_0);
    return select(latest.field_0) {
	0       : ingress;
	default : parse_header_1;

    }
}
header_type header_1_t {
    fields {
		field_0 : 16;

    }
}
header header_1_t header_1;

parser parse_header_1 {
    extract(header_1);
    return select(latest.field_0) {
	0       : ingress;
	default : parse_header_2;

    }
}
header_type header_2_t {
    fields {
		field_0 : 16;

    }
}
header header_2_t header_2;

parser parse_header_2 {
    extract(header_2);
    return select(latest.field_0) {
	0       : ingress;
	default : parse_header_3;

    }
}
header_type header_3_t {
    fields {
		field_0 : 16;

    }
}
header header_3_t header_3;

parser parse_header_3 {
    extract(header_3);
    return select(latest.field_0) {
	0       : ingress;
	default : parse_header_4;

    }
}
header_type header_4_t {
    fields {
		field_0 : 16;

    }
}
header header_4_t header_4;

parser parse_header_4 {
    extract(header_4);
    return select(latest.field_0) {
	default : ingress;

    }
}
action _drop() {
    drop();
}

action forward(port) {
    modify_field(standard_metadata.egress_spec, port);
}

table forward_table {
    reads {
        ethernet.dstAddr : exact;
    } actions {
        forward;
        _drop;
    }
    size : 4;
}
control ingress {
    apply(forward_table);
    
}
