# JGStatic

## Globals

StaticCompiler compiles each exported function into its own object file, so a Julia `global` is not shared. Put one LLVM global in a slot function and list that function in `functions_table.jl`. That object file owns the storage.

```julia
function example_slot(do_set::Int32, value::UInt64)::UInt64
    Base.llvmcall(("""
                   @g_example = global i64 0
                   define i64 @main(i32 %do_set, i64 %value) {
                       entry:
                       %set = icmp ne i32 %do_set, 0
                       br i1 %set, label %write, label %read
                       write:
                       store i64 %value, i64* @g_example
                       ret i64 %value
                       read:
                       %v = load i64, i64* @g_example
                       ret i64 %v
                       }
                       """, "main"), UInt64, Tuple{Int32, UInt64}, do_set, value)
end
```

`do_set != 0` writes `value` and returns it. `do_set == 0` returns the stored value. Pointers are stored as `UInt64` with `reinterpret`.

Other functions must not call `example_slot` as Julia. That compiles `@g_example` into their object file too and the link fails with a multiple definition. Declare the slot and call that symbol:

```julia
function llvm_get_example()::UInt64
    return Base.llvmcall(("""
                          declare i64 @example_slot(i32, i64) nounwind
                          define i64 @main() {
                              entry:
                              %r = call i64 @example_slot(i32 0, i64 0)
                              ret i64 %r
                              }
                              """, "main"), UInt64, Tuple{},)
end

function llvm_set_example(value::UInt64)
    Base.llvmcall(("""
                   declare i64 @example_slot(i32, i64) nounwind
                   define void @main(i64 %value) {
                       entry:
                       call i64 @example_slot(i32 1, i64 %value)
                       ret void
                       }
                       """, "main"), Cvoid, Tuple{UInt64}, value)
    return
end
```

`renderer_slot`, `scene_slot`, and `fps_slot` follow this.
