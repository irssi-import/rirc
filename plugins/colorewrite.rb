class ColoRewrite < Plugin
    
    def rgb2xyz(r, g, b)
        r /= 255.0
        g /= 255.0
        b /= 255.0
        
        if r > 0.04045
            r = ( ( r + 0.055 ) / 1.055 ) ** 2.4
        else
            r = r / 12.92
        end
        
        if g > 0.04045
            g = ( ( g + 0.055 ) / 1.055 ) ** 2.4
        else
            g = g / 12.92
        end
        
        if b > 0.04045
            b = ( ( b + 0.055 ) / 1.055 ) ** 2.4
        else
            b = b / 12.92
        end
        
        r *= 100
        g *= 100
        b *= 100
        
        x = (r * 0.4124) + (g * 0.3576) + (b * 0.1805)
        y = (r * 0.2126) + (g * 0.7152) + (b * 0.0722)
        z = (r * 0.0193) + (g * 0.1192) + (b * 0.9505)
        return [x,y,z]
    end
    
    def xyz2rgb(x, y, z)
        x /= 100
        y /= 100
        z /= 100
        
        r = x *  3.2406 + y * -1.5372 + z * -0.4986
        g = x * -0.9689 + y *  1.8758 + z *  0.0415
        b = x *  0.0557 + y * -0.2040 + z *  1.0570
        
        if r > 0.0031308
            r = 1.055 * ( r ** ( 1 / 2.4 ) ) - 0.055
        else
            r *= 12.92
        end
        
        if g > 0.0031308
            g = 1.055 * ( g ** ( 1 / 2.4 ) ) - 0.055
        else
            g *= 12.92
        end
        
        if b > 0.0031308
            b = 1.055 * ( b ** ( 1 / 2.4 ) ) - 0.055
        else
            b *= 12.92
        end
    
        
        r *= 255
        g *= 255
        b *= 255
        
        r = r.to_i.abs
        g = g.to_i.abs
        b = b.to_i.abs
        
        r = 255 if r > 255
        g = 255 if g > 255
        b = 255 if b > 255
        
        return[r,g,b]
    end
    
    def xyz2lab(x, y, z)
        x /= 95.047
        y /= 100.000
        z /= 108.883
        
        if x > 0.008856
            x **= ( 1/3.0 )
        else
            x = ( 7.787 * x ) + ( 16 / 116.0 )
        end
        
        if y > 0.008856
            y **= ( 1/3.0 )
        else
            y = ( 7.787 * y ) + ( 16 / 116.0 )
        end
        
        if z > 0.008856
            z **= ( 1/3.0 )
        else
            z = ( 7.787 * z ) + ( 16 / 116.0 )
        end
        
        l = ( 116 * y ) - 16
        a = 500 * ( x - y )
        b = 200 * ( y - z )
        
        return [l,a,b]
    end
    
    def lab2xyz(l, a, b)
        l = ( l + 16 ) / 116
        a = a / 500 + l
        b = l - b / 200
        
        if l**3 > 0.008856
            l = l**3
        else
            l = ( l - 16 / 116 ) / 7.787
        end
        
        if a**3 > 0.008856
            a = a**3
        else
            a = ( a - 16 / 116 ) / 7.787
        end
        
        if b**3 > 0.008856
            b = b**3
        else
            b = ( b - 16 / 116 ) / 7.787
        end
        
        x = a * 95.047
        y = l * 100.000
        z = b * 108.883
        
        return[x,y,z]
    end
    
    def colorcompare(r1, g1, b1, r2, g2, b2)
        a = xyz2lab(*rgb2xyz(r1, g1, b1))
        b = xyz2lab(*rgb2xyz(r2, g2, b2))
        
        l1, a1, b1 = a
        l2, a2, b2 = b
    
        res = [(l1-l2).abs, (a1-a2).abs, (b1-b2).abs]
        if res.select{|e| e/100 > 0.5}.length >= 2
            return true
        else
            result = false
            while result != true
                #b[res.index(res.sort[2])]-= 5
                b[res.index(res.sort[1])]+= 10
                b[res.index(res.sort[0])]-= 1
                #puts b[res.index(res.sort[1])]
                l2, a2, b2 = b
                result = [(l1-l2).abs, (a1-a2).abs, (b1-b2).abs].select{|e| e/100 > 0.6}.length >= 2
            end
            return xyz2rgb(*lab2xyz(*b))
        end
    end
    
    def load
    
        add_callback_after(self, Buffer, 'buffer_message') do |local, uname, pattern, users, insert_location|
            #puts pattern
            pattern.scan(/\<span foreground\s*=\s*\"#([0-9a-f]+)/i) do |m|
                puts pattern, m
                puts Color.hex_to_a($1), $config['scw_even'].to_256
                res = colorcompare(*($config['scw_even'].to_256+Color.hex_to_a($1)))
                puts res
                if res.class == Array
                    hexcolor = Color.a_to_hex(res)
                    puts 'match'
                    pattern.sub!($1, hexcolor)
                end
                puts pattern
            end
            [uname, pattern, users, insert_location]
        end
    end
end

colorewrite = ColoRewrite.new
Plugin.register(colorewrite)
    
#puts colorcompare(255, 255, 255, 255, 255, 0)

#puts xyz2rgb(*lab2xyz(*xyz2lab(*rgb2xyz(255, 255, 255))))

