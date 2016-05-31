require 'yaml'

class NeuralNetwork
  class WrongNumberOfInputsError < RuntimeError; end

  attr_reader :number_of_inputs, :number_of_outputs, :number_of_medial_neurons,
              :learning_rate, :bias_neuron, :target_proc, :input_proc

  # Create a new neural network
  #
  # You can supply custom input and target procs, which should return Arrays of
  # random inputs and expected outputs given those inputs respectively. Both
  # procs should return Array objects, even if they only include a single
  # element.
  #
  # We will infer the number of input and ouput neurons using the number of
  # elements returned by those procs, and whether or not the `bias_neuron`
  # option is set.
  #
  # The learning rate can also be set (default: 0.01), and the number of medial
  # neurons (default: 40).
  def initialize(target_proc: nil, input_proc: nil, bias_neuron: 2.0,
                 number_of_medial_neurons: 40, learning_rate: 0.01)
    @input_proc = input_proc || -> { [rand, rand * 2 * Math::PI] }
    @target_proc = target_proc || -> (r, a) { Complex.polar(r, a).rectangular }

    @number_of_inputs = input_proc.call.length
    @number_of_inputs += 1 if bias_neuron != nil

    @number_of_outputs = target_proc.call(*input_proc.call).length

    @number_of_medial_neurons = number_of_medial_neurons

    @learning_rate = learning_rate
    @bias_neuron = bias_neuron
    @average_error = nil
    @training_iterations = 0

    # Initialize the synapse weightings using random numbers
    # `@synone` contains the synapse weights between every input neuron and every
    # medial neuron.
    # `@syntwo` contais the synapse weights between every medial neuron and every
    # output neuron.
    @synone = @number_of_inputs.times.map { @number_of_medial_neurons.times.map { 0.1 * rand } }
    @syntwo = @number_of_medial_neurons.times.map { @number_of_outputs.times.map { 0.1 * rand } }
  end

  # Compute the output values for the current network, given values for all
  # input neurons (INCLUDING any bias neuron). To add the bias neuron value
  # automatically, use the result of the `inputs_with_bias` method below.
  def compute(*inputs)
    if inputs.length != number_of_inputs
      raise WrongNumberOfInputsError, "Expected #{number_of_inputs} inputs, got #{inputs.length}"
    end

    # Stash these in instance variables so we can use them for training later
    @medin = []
    @medout = []

    outputs = []

    number_of_medial_neurons.times do |i|
      @medin[i] = 0
      number_of_inputs.times do |j|
        @medin[i] += @synone[j][i] * inputs[j]
      end
      @medout[i] = Math.tanh(@medin[i])
    end

    number_of_outputs.times do |i|
      outputs[i] = 0
      number_of_medial_neurons.times do |j|
        outputs[i] += @syntwo[j][i] * @medout[j]
      end
    end

    outputs
  end

  # Train this network for the given number of iterations
  # We track the average error as it changes during training, and also the
  # difference between the average error before and after training is complete.
  # This helps see whether or not training is continuing to improve the network,
  # or if we have hit a (possibly-local) minima.
  def train(iterations=1)
    all_errors = []

    1.upto(iterations) do |iteration|
      arguments = input_proc.call
      target_outputs = target_proc.call(*arguments)
      inputs = inputs_with_bias(arguments)
      actual_outputs = compute(*inputs)
      errors = actual_outputs.zip(target_outputs).map { |actual, target| target - actual }

      number_of_outputs.times do |i|
        number_of_medial_neurons.times do |j|
          @syntwo[j][i] += (learning_rate * @medout[j] * errors[i])
        end
      end

      sigma = []
      sigmoid = []

      number_of_medial_neurons.times do |i|
        sigma[i] = 0
        number_of_outputs.times do |j|
          sigma[i] = sigma[i] + errors[j] * @syntwo[i][j]
        end
        sigmoid[i] = 1 - @medout[i]**2
      end

      number_of_inputs.times do |i|
        number_of_medial_neurons.times do |j|
          delta = learning_rate * sigmoid[j] * sigma[j] * inputs[i]
          @synone[i][j] += delta
        end
      end

      overall_error = Math.sqrt(errors.map { |e| e**2 }.inject(:+))
      print "\r[#{iteration}] error: #{overall_error}"

      all_errors << overall_error
      @training_iterations += 1
    end

    new_average_error = all_errors.inject(:+) / all_errors.length
    if @average_error.nil?
      puts "\nAverage error is now #{new_average_error}"
    else
      better_or_worse = (@average_error - new_average_error) > 0 ? 'BETTER' : 'WORSE'
      puts "\nAverage error is #{better_or_worse} (#{@average_error} => #{new_average_error})"
    end
    @average_error = new_average_error
  end

  # Returns an array of inputs for the `compute` method, with the value of the
  # "bias" neuron included as the final input neuron value
  def inputs_with_bias(inputs)
    result = inputs.dup
    result << bias_neuron if bias_neuron
    result
  end

  # Loads a network state from a YAML file
  def load_from_file(path)
    YAML.load_file(path).each { |n,v| instance_variable_set(n, v) }
  end

  # Saves the current network state (settings and synapse weights) to a YAML file
  def save_to_file(path)
    variables_to_save = instance_variables.reject { |v| v =~ /_proc$/ || v =~ /^@med/ }
    File.open(path, 'w') { |f| f.puts(
      variables_to_save.inject({}) { |h,n| h[n] = instance_variable_get(n); h }.to_yaml
    ) }
  end
end

if __FILE__ == $0
  require 'optparse'

  # Computation configuration for various different applications. Remember that
  # every proc needs to return an Array.
  procs = {
    'addition' => {
      input_proc: -> { [rand * 10, rand * 10] },
      target_proc: -> (x, y) { [x + y] }
    },
    'integer-addition' => {
      input_proc: -> { [rand(10), rand(10)] },
      target_proc: -> (x, y) { [x + y] }
    },
    'polar' => {
      input_proc: -> { [rand, rand * 2 * Math::PI] },
      target_proc: -> (r, a) { Complex.polar(r, a).rectangular },
    }
  }

  $name = 'polar'
  options = procs[$name]

  OptionParser.new do |opts|
    opts.banner = "Usage: #{__FILE__} [options]"
    opts.on("-h", "--help", "Show this message") { puts opts; exit }
    opts.on("-t", "--train [ITERATIONS]", Integer) { |i| $iterations = i }
    opts.on("-n", "--name [NAME]", String) { |n| $name = n; options.merge!(procs[n]) }
    opts.on("-f", "--file [PATH]", String) { |f| $file = f }
    opts.on("-m", "--medial [NUMBER]", Integer) { |m| options[:number_of_medial_neurons] = m }
    opts.on("-b", "--bias [NUMBER]", Float) { |b| options[:bias_neuron] = b }
    opts.on("--no-bias") { options[:bias_neuron] = nil }
    opts.on("-r", "--rate [NUMBER]", Float) { |r| options[:learning_rate] = r }
  end.parse!

  $file ||= "#{$name}.yml"

  at_exit { $network.save_to_file($file) if $file }

  $network = NeuralNetwork.new(options)

  $network.load_from_file($file) if $file && File.exist?($file)

  if $iterations
    $network.train($iterations)
  else
    begin
      inputs = ARGV.map(&:to_f)
      result = $network.compute(*$network.inputs_with_bias(inputs))
      expected = $network.target_proc.call(*inputs)
      error = result.zip(expected).map { |(r,e)| e - r }

      input_string = "#{inputs.inspect} => "
      result = "#{input_string}#{result.inspect}"
      expected = "#{' ' * (input_string.length - 9)}expected #{expected.inspect}"
      error = "#{' ' * (input_string.length - 11)}difference #{error.inspect}"
      puts [result, expected, error].join("\n")
    rescue NeuralNetwork::WrongNumberOfInputsError => e
      puts "#{e.message}; maybe you need to provide some inputs as arguments?"
    end
  end
end
