function normal(shader, t_base, t_second, t_detail)
    shader:begin("ui_actor_wave", "ui_actor_wave")
        :fog(false)
        :zb(false, false)
        :blend(true, blend.srcalpha, blend.one)
        :aref(false, 0)
    shader:dx10texture("s_base", t_base)
    shader:dx10sampler("smp_base")
end
