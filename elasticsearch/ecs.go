package elasticsearch

import "github.com/jasonish/evebox/util"

var EcsFieldMap FieldMap

func init() {
	EcsFieldMap = FieldMap{
		"event_type": "suricata.eve.event_type",
	}
}

func EcsRowMap(hit util.JsonMap) {

}