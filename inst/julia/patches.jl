# Monkey-patch for Omniscape.jl compatibility with Julia >= 1.12
# The missingarray_to_array method's type parameter matching doesn't work
# correctly for Matrix types in Julia 1.12+.
# This adds fully concrete methods for Float64 and Float32 cases.
if isdefined(Omniscape, :missingarray_to_array)
    @eval function Omniscape.missingarray_to_array(
            A::Matrix{Union{Missing, Float64}},
            nodata::Number
        )
        output = copy(A)
        output[ismissing.(output)] .= nodata
        return convert(Matrix{Float64}, output)
    end

    @eval function Omniscape.missingarray_to_array(
            A::Matrix{Union{Missing, Float32}},
            nodata::Number
        )
        output = copy(A)
        output[ismissing.(output)] .= nodata
        return convert(Matrix{Float32}, output)
    end
end
