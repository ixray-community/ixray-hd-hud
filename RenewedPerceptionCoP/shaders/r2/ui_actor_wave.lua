function normal(shader, t_base, t_second, t_detail)
    shader:begin("ui_actor_wave", "ui_actor_wave")
        :fog(false)
        :zb(false, false)
        :blend(true, blend.srcalpha, blend.one)
        :aref(false, 0)
    shader:sampler("s_base"):texture(t_base):clamp():f_linear()
end
