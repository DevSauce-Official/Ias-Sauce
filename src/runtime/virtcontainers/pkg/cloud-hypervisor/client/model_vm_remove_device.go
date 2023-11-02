/*
Cloud Hypervisor API

Local HTTP based API for managing and inspecting a cloud-hypervisor virtual machine.

API version: 0.3.0
*/

// Code generated by OpenAPI Generator (https://openapi-generator.tech); DO NOT EDIT.

package openapi

import (
	"encoding/json"
)

// VmRemoveDevice struct for VmRemoveDevice
type VmRemoveDevice struct {
	Id *string `json:"id,omitempty"`
}

// NewVmRemoveDevice instantiates a new VmRemoveDevice object
// This constructor will assign default values to properties that have it defined,
// and makes sure properties required by API are set, but the set of arguments
// will change when the set of required properties is changed
func NewVmRemoveDevice() *VmRemoveDevice {
	this := VmRemoveDevice{}
	return &this
}

// NewVmRemoveDeviceWithDefaults instantiates a new VmRemoveDevice object
// This constructor will only assign default values to properties that have it defined,
// but it doesn't guarantee that properties required by API are set
func NewVmRemoveDeviceWithDefaults() *VmRemoveDevice {
	this := VmRemoveDevice{}
	return &this
}

// GetId returns the Id field value if set, zero value otherwise.
func (o *VmRemoveDevice) GetId() string {
	if o == nil || o.Id == nil {
		var ret string
		return ret
	}
	return *o.Id
}

// GetIdOk returns a tuple with the Id field value if set, nil otherwise
// and a boolean to check if the value has been set.
func (o *VmRemoveDevice) GetIdOk() (*string, bool) {
	if o == nil || o.Id == nil {
		return nil, false
	}
	return o.Id, true
}

// HasId returns a boolean if a field has been set.
func (o *VmRemoveDevice) HasId() bool {
	if o != nil && o.Id != nil {
		return true
	}

	return false
}

// SetId gets a reference to the given string and assigns it to the Id field.
func (o *VmRemoveDevice) SetId(v string) {
	o.Id = &v
}

func (o VmRemoveDevice) MarshalJSON() ([]byte, error) {
	toSerialize := map[string]interface{}{}
	if o.Id != nil {
		toSerialize["id"] = o.Id
	}
	return json.Marshal(toSerialize)
}

type NullableVmRemoveDevice struct {
	value *VmRemoveDevice
	isSet bool
}

func (v NullableVmRemoveDevice) Get() *VmRemoveDevice {
	return v.value
}

func (v *NullableVmRemoveDevice) Set(val *VmRemoveDevice) {
	v.value = val
	v.isSet = true
}

func (v NullableVmRemoveDevice) IsSet() bool {
	return v.isSet
}

func (v *NullableVmRemoveDevice) Unset() {
	v.value = nil
	v.isSet = false
}

func NewNullableVmRemoveDevice(val *VmRemoveDevice) *NullableVmRemoveDevice {
	return &NullableVmRemoveDevice{value: val, isSet: true}
}

func (v NullableVmRemoveDevice) MarshalJSON() ([]byte, error) {
	return json.Marshal(v.value)
}

func (v *NullableVmRemoveDevice) UnmarshalJSON(src []byte) error {
	v.isSet = true
	return json.Unmarshal(src, &v.value)
}