-- Marker table for IInitializable. Returned as a unique reference;
-- classes that implement this interface emit `__interfaces = {..., IInitializable}`
-- and the container's Bootstrap walks bindings looking for that marker.

return {}
