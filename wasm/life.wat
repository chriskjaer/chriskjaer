(module
  (memory (export "memory") 2 8)
  (global $g_w (mut i32) (i32.const 0))
  (global $g_h (mut i32) (i32.const 0))
  (global $g_size (mut i32) (i32.const 0))
  (global $g_cur (mut i32) (i32.const 0))
  (global $g_next (mut i32) (i32.const 0))

  (func (export "set_size") (param $w i32) (param $h i32)
    (local $size i32)
    (local $needed i32)
    (local $pages i32)
    (local $cur_pages i32)
    local.get $w
    local.get $h
    i32.mul
    local.set $size
    local.get $w
    global.set $g_w
    local.get $h
    global.set $g_h
    local.get $size
    global.set $g_size
    local.get $size
    i32.const 2
    i32.mul
    local.set $needed
    local.get $needed
    i32.const 65535
    i32.add
    i32.const 65536
    i32.div_u
    local.set $pages
    memory.size
    local.set $cur_pages
    local.get $pages
    local.get $cur_pages
    i32.gt_u
    if
      local.get $pages
      local.get $cur_pages
      i32.sub
      memory.grow
      drop
    end
    i32.const 0
    global.set $g_cur
    local.get $size
    global.set $g_next
  )

  (func (export "ptr") (result i32)
    global.get $g_cur
  )

  (func (export "step")
    (local $x i32)
    (local $y i32)
    (local $xprev i32)
    (local $xnext i32)
    (local $yprev i32)
    (local $ynext i32)
    (local $row_prev i32)
    (local $row_cur i32)
    (local $row_next i32)
    (local $count i32)
    (local $alive i32)
    (local $nextval i32)
    (local $cur i32)
    (local $next i32)
    (local $tmp i32)

    global.get $g_cur
    local.set $cur
    global.get $g_next
    local.set $next

    i32.const 0
    local.set $y
    (block $y_done
      (loop $y_loop
        local.get $y
        global.get $g_h
        i32.ge_u
        br_if $y_done

        local.get $y
        i32.eqz
        if (result i32)
          global.get $g_h
          i32.const 1
          i32.sub
        else
          local.get $y
          i32.const 1
          i32.sub
        end
        local.set $yprev

        local.get $y
        i32.const 1
        i32.add
        local.set $ynext
        local.get $ynext
        global.get $g_h
        i32.eq
        if
          i32.const 0
          local.set $ynext
        end

        local.get $yprev
        global.get $g_w
        i32.mul
        local.set $row_prev
        local.get $y
        global.get $g_w
        i32.mul
        local.set $row_cur
        local.get $ynext
        global.get $g_w
        i32.mul
        local.set $row_next

        i32.const 0
        local.set $x
        (block $x_done
          (loop $x_loop
            local.get $x
            global.get $g_w
            i32.ge_u
            br_if $x_done

            local.get $x
            i32.eqz
            if (result i32)
              global.get $g_w
              i32.const 1
              i32.sub
            else
              local.get $x
              i32.const 1
              i32.sub
            end
            local.set $xprev

            local.get $x
            i32.const 1
            i32.add
            local.set $xnext
            local.get $xnext
            global.get $g_w
            i32.eq
            if
              i32.const 0
              local.set $xnext
            end

            i32.const 0
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_prev
            i32.add
            local.get $xprev
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_prev
            i32.add
            local.get $x
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_prev
            i32.add
            local.get $xnext
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_cur
            i32.add
            local.get $xprev
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_cur
            i32.add
            local.get $xnext
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_next
            i32.add
            local.get $xprev
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_next
            i32.add
            local.get $x
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $count
            local.get $cur
            local.get $row_next
            i32.add
            local.get $xnext
            i32.add
            i32.load8_u
            i32.add
            local.set $count

            local.get $cur
            local.get $row_cur
            i32.add
            local.get $x
            i32.add
            i32.load8_u
            local.set $alive

            local.get $alive
            if (result i32)
              local.get $count
              i32.const 2
              i32.eq
              local.get $count
              i32.const 3
              i32.eq
              i32.or
            else
              local.get $count
              i32.const 3
              i32.eq
            end
            local.set $nextval

            local.get $next
            local.get $row_cur
            i32.add
            local.get $x
            i32.add
            local.get $nextval
            i32.store8

            local.get $x
            i32.const 1
            i32.add
            local.set $x
            br $x_loop
          )
        )

        local.get $y
        i32.const 1
        i32.add
        local.set $y
        br $y_loop
      )
    )

    global.get $g_cur
    local.set $tmp
    global.get $g_next
    global.set $g_cur
    local.get $tmp
    global.set $g_next
  )
)
