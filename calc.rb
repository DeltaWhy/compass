@last = 0.0
def calc(expr)
    puts "calc(#{expr.inspect})"
    expr = expr.gsub('**','^')
    tokens = []
    pos = 0
    until pos >= expr.length
        pos += 1 while expr[pos] =~ /\s/
        case expr[pos]
        when '0'..'9','.'
            token = ''
            while ('0'..'9').include? expr[pos] or expr[pos] == '.'
                token += expr[pos]
                pos += 1
            end
            tokens.push(token.to_f)
        when 'a'..'z'
            token = ''
            while ('a'..'z').include? expr[pos]
                token += expr[pos]
                pos += 1
            end
            tokens.push(token)
        when '+','-','*','/','^','(',')',',','~'
            tokens.push(expr[pos])
            pos += 1
        when '_'
            tokens.push(@last)
            pos += 1
        else
            return nil
        end
    end
    puts tokens.inspect

    #handle unary -
    for i in 0..(tokens.length)
        next unless tokens[i] == '-'
        if i == 0 or '^*/+-~,('.include? tokens[i-1].to_s or tokens[i-1] =~ /^[a-z]+$/
            tokens[i] = '~'
        end
    end
    puts tokens.inspect

    postfix = []
    stack = []
    tokens.each do |token|
        case token
        when Float, Fixnum, Array
            postfix.push(token)
        when '('
            stack.push(token)
        when ')'
            postfix.push(stack.pop) until stack.empty? or stack[-1] == '('
            return nil if stack.empty?
            stack.pop
            postfix.push(stack.pop) if stack[-1] =~ /^[a-z]+$/
        when '^'
            postfix.push(stack.pop) while stack[-1] == '^'
            stack.push(token)
        when /^[a-z]+$/
            stack.push(token)
        when '~'
            stack.push(token)
        when '*','/'
            postfix.push(stack.pop) while !stack.empty? and '^~*/'.include? stack[-1]
            stack.push(token)
        when '+','-'
            postfix.push(stack.pop) while !stack.empty? and '^~*/+-'.include? stack[-1]
            stack.push(token)
        when ','
            postfix.push(stack.pop) while !stack.empty? and '^~*/+-,'.include? stack[-1]
            stack.push(token)
        end
    end
    postfix.push(stack.pop) until stack.empty?

    puts postfix.inspect
    postfix.each do |token|
        case token
        when Float, Fixnum, Array
            stack.push(token)
        when '^'
            a, b = stack.pop, stack.pop
            stack.push(b**a)
        when ','
            a, b = stack.pop, stack.pop
            if Array === b
                stack.push(b.push(a))
            else
                stack.push([b,a])
            end
        when '~'
            a = stack.pop
            if Array === a
                stack.push(a.map{|x| -x})
            else
                stack.push(-a)
            end
        when '*'
            a, b = stack.pop, stack.pop
            if Array === b
                stack.push(b.map{|x| x*a})
            elsif Array === a
                stack.push(a.map{|x| b*x})
            else
                stack.push(b*a)
            end
        when '/'
            a, b = stack.pop, stack.pop
            if Array === b
                stack.push(b.map{|x| x/a})
            elsif Array === a
                stack.push(a.map{|x| b/x})
            else
                stack.push(b/a)
            end
        when '+'
            a, b = stack.pop, stack.pop
            if Array === b and Array === a
                return nil unless b.length === a.length
                stack.push(b.zip(a).map{|(x,y)| x+y})
            elsif Array === b
                stack.push(b.map{|x| x+a})
            elsif Array === a
                stack.push(a.map{|x| b+x})
            else
                stack.push(b+a)
            end
        when '-'
            a, b = stack.pop, stack.pop
            if Array === b and Array === a
                return nil unless b.length === a.length
                stack.push(b.zip(a).map{|(x,y)| x-y})
            elsif Array === b
                stack.push(b.map{|x| x-a})
            elsif Array === a
                stack.push(a.map{|x| b-x})
            else
                stack.push(b-a)
            end
        when 'sqrt'
            stack.push(Math.sqrt(stack.pop))
        when 'sum'
            stack.push(stack.pop.inject(&:+))
        when 'abs'
            a = stack.pop
            if Array === a
                stack.push(a.map{|x| x < 0 ? -x : x})
            else
                stack.push(a < 0 ? -a : a)
            end
        when 'length', 'magnitude', 'mag', 'len', 'distance', 'dist'
            a = stack.pop
            a.map{|x| x**2}
            stack.push(Math.sqrt(a.inject(&:+)))
        else
            return nil
        end
    end

    @last = stack[0]
end
