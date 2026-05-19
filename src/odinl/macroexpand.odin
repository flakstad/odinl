package odinl

import "core:fmt"
import "core:strings"
import "base:runtime"

Macro_Expander :: struct {
    builder:    strings.Builder,
    line:       int,
    source_map: ^[dynamic]Source_Map_Entry,
}

macro_record_source_map :: proc(e: ^Macro_Expander, start_line, end_line: int, span: Span) {
    if e.source_map == nil || end_line < start_line {
        return
    }
    append(e.source_map, Source_Map_Entry{
        generated_start_line = start_line,
        generated_end_line   = end_line,
        source_span          = span,
    })
}

macro_emit_line :: proc(e: ^Macro_Expander, text: string, span: Span) {
    strings.write_string(&e.builder, text)
    strings.write_byte(&e.builder, '\n')
    macro_record_source_map(e, e.line, e.line, span)
    e.line += 1
}

write_macro_form :: proc(builder: ^strings.Builder, form: CST_Form) {
    #partial switch form.kind {
    case .List:
        strings.write_byte(builder, '(')
        for item, idx in form.items {
            if idx > 0 {
                strings.write_byte(builder, ' ')
            }
            write_macro_form(builder, item)
        }
        strings.write_byte(builder, ')')
    case .Vector:
        strings.write_byte(builder, '[')
        for item, idx in form.items {
            if idx > 0 {
                strings.write_byte(builder, ' ')
            }
            write_macro_form(builder, item)
        }
        strings.write_byte(builder, ']')
    case .Brace:
        strings.write_byte(builder, '{')
        for item, idx in form.items {
            if idx > 0 {
                strings.write_byte(builder, ' ')
            }
            write_macro_form(builder, item)
        }
        strings.write_byte(builder, '}')
    case .Symbol, .Keyword, .String, .Number, .Bool, .Nil:
        strings.write_string(builder, form.text)
    }
}

macro_form_text :: proc(form: CST_Form) -> string {
    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    write_macro_form(&builder, form)
    return strings.clone(strings.to_string(builder))
}

macroexpand_with_allocator :: proc(form: CST_Form) -> (result: Emit_Result, err: Compile_Error, ok: bool) {
    if len(form.items) < 3 || form.items[1].kind != .Vector {
        return result, Compile_Error{message = "with-allocator expects binding vector and body", span = form.span}, false
    }
    binding := form.items[1]
    if len(binding.items) != 2 || binding.items[0].kind != .Symbol {
        return result, Compile_Error{message = "with-allocator expects [name allocator] binding", span = binding.span}, false
    }

    allocator_name := binding.items[0].text
    allocator_expr := macro_form_text(binding.items[1])
    defer delete(allocator_expr)

    e := Macro_Expander{builder = strings.builder_make(), line = 1, source_map = &result.source_map}
    defer strings.builder_destroy(&e.builder)

    macro_emit_line(&e, "(do", form.span)
    macro_emit_line(&e, fmt.tprintf("  (let [%s %s", allocator_name, allocator_expr), binding.items[1].span)
    macro_emit_line(&e, "        odinl-old-allocator-1 context.allocator]", form.span)
    macro_emit_line(&e, fmt.tprintf("    (set! context.allocator %s)", allocator_name), form.span)
    macro_emit_line(&e, "    (defer (do", form.span)
    macro_emit_line(&e, "      (set! context.allocator odinl-old-allocator-1)))", form.span)
    body := form.items[2:]
    for item, idx in body {
        item_text := macro_form_text(item)
        defer delete(item_text)
        suffix := ""
        if idx == len(body)-1 {
            suffix = "))"
        }
        macro_emit_line(&e, fmt.tprintf("    %s%s", item_text, suffix), item.span)
    }

    result.output = strings.clone(strings.to_string(e.builder))
    return result, {}, true
}

macroexpand_with_temp_allocator :: proc(form: CST_Form) -> (result: Emit_Result, err: Compile_Error, ok: bool) {
    if len(form.items) < 3 || form.items[1].kind != .Vector {
        return result, Compile_Error{message = "with-temp-allocator expects binding vector and body", span = form.span}, false
    }
    binding := form.items[1]
    if len(binding.items) != 1 || binding.items[0].kind != .Symbol {
        return result, Compile_Error{message = "with-temp-allocator expects [name] binding", span = binding.span}, false
    }

    allocator_name := binding.items[0].text

    e := Macro_Expander{builder = strings.builder_make(), line = 1, source_map = &result.source_map}
    defer strings.builder_destroy(&e.builder)

    macro_emit_line(&e, "(do", form.span)
    macro_emit_line(&e, "  (let [odinl-temp-scope-1 (runtime.default-temp-allocator-temp-begin)", form.span)
    macro_emit_line(&e, fmt.tprintf("        %s context.temp-allocator", allocator_name), form.span)
    macro_emit_line(&e, "        odinl-old-allocator-1 context.allocator]", form.span)
    macro_emit_line(&e, fmt.tprintf("    (set! context.allocator %s)", allocator_name), form.span)
    macro_emit_line(&e, "    (defer (do", form.span)
    macro_emit_line(&e, "      (set! context.allocator odinl-old-allocator-1)", form.span)
    macro_emit_line(&e, "      (runtime.default-temp-allocator-temp-end odinl-temp-scope-1)))", form.span)
    body := form.items[2:]
    for item, idx in body {
        item_text := macro_form_text(item)
        defer delete(item_text)
        suffix := ""
        if idx == len(body)-1 {
            suffix = "))"
        }
        macro_emit_line(&e, fmt.tprintf("    %s%s", item_text, suffix), item.span)
    }

    result.output = strings.clone(strings.to_string(e.builder))
    return result, {}, true
}

macroexpand_with_delete :: proc(form: CST_Form) -> (result: Emit_Result, err: Compile_Error, ok: bool) {
    if len(form.items) < 3 || form.items[1].kind != .Vector {
        return result, Compile_Error{message = "with-delete expects binding vector and body", span = form.span}, false
    }
    binding := form.items[1]
    if len(binding.items) < 2 || len(binding.items)%2 != 0 {
        return result, Compile_Error{message = "with-delete expects [name value ...] bindings", span = binding.span}, false
    }

    e := Macro_Expander{builder = strings.builder_make(), line = 1, source_map = &result.source_map}
    defer strings.builder_destroy(&e.builder)

    macro_emit_line(&e, "(do", form.span)
    i := 0
    for i < len(binding.items) {
        if binding.items[i].kind != .Symbol {
            return result, Compile_Error{message = "with-delete binding name must be a symbol", span = binding.items[i].span}, false
        }
        binding_name := binding.items[i].text
        value_expr := macro_form_text(binding.items[i+1])
        defer delete(value_expr)
        suffix := ""
        if i+2 >= len(binding.items) {
            suffix = "]"
        }
        if i == 0 {
            macro_emit_line(&e, fmt.tprintf("  (let [%s %s%s", binding_name, value_expr, suffix), binding.items[i+1].span)
        } else {
            macro_emit_line(&e, fmt.tprintf("        %s %s%s", binding_name, value_expr, suffix), binding.items[i+1].span)
        }
        i += 2
    }
    i = 0
    for i < len(binding.items) {
        binding_name := binding.items[i].text
        macro_emit_line(&e, fmt.tprintf("    (defer (delete %s))", binding_name), binding.items[i].span)
        i += 2
    }
    body := form.items[2:]
    for item, idx in body {
        item_text := macro_form_text(item)
        defer delete(item_text)
        suffix := ""
        if idx == len(body)-1 {
            suffix = "))"
        }
        macro_emit_line(&e, fmt.tprintf("    %s%s", item_text, suffix), item.span)
    }

    result.output = strings.clone(strings.to_string(e.builder))
    return result, {}, true
}

macroexpand_form :: proc(form: CST_Form) -> (result: Emit_Result, err: Compile_Error, ok: bool) {
    if form.kind == .List && len(form.items) > 0 && form.items[0].kind == .Symbol {
        switch form.items[0].text {
        case "with-allocator":
            return macroexpand_with_allocator(form)
        case "with-temp-allocator":
            return macroexpand_with_temp_allocator(form)
        case "with-delete":
            return macroexpand_with_delete(form)
        }
    }

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)
    write_macro_form(&builder, form)
    strings.write_byte(&builder, '\n')
    result.output = strings.clone(strings.to_string(builder))
    append(&result.source_map, Source_Map_Entry{
        generated_start_line = 1,
        generated_end_line = 1,
        source_span = form.span,
    })
    return result, {}, true
}

macroexpand_source :: proc(source: string) -> (output: string, err: Compile_Error, ok: bool) {
    result, err_result, ok_result := macroexpand_source_with_map(source)
    if !ok_result {
        return "", err_result, false
    }
    defer delete(result.source_map)
    return result.output, {}, true
}

macroexpand_source_with_map :: proc(source: string) -> (result: Emit_Result, err: Compile_Error, ok: bool) {
    result_allocator := context.allocator
    old_allocator := context.allocator
    temp_scope := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp_scope)
    context.allocator = context.temp_allocator
    defer context.allocator = old_allocator

    form, err_form, ok_form := read_single_eval_form(source)
    if !ok_form {
        return result, clone_compile_error(err_form, result_allocator), false
    }
    temp_result, err_expand, ok_expand := macroexpand_form(form)
    if !ok_expand {
        return result, clone_compile_error(err_expand, result_allocator), false
    }
    result.output = strings.clone(temp_result.output, result_allocator)
    context.allocator = result_allocator
    for entry in temp_result.source_map {
        append(&result.source_map, entry)
    }
    return result, {}, true
}
