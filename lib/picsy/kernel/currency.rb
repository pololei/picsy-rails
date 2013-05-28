load 'constant.rb'

module Picsy
module Kernel
class Currency
  @deleted_persons = [] # �폜���ꂽ�l�̃��X�g
  @id # �ݕ�ID

  @persons = []
  @algorithm_type = 1
  @sync_type = 0

  @max_markov_process = Constant::DEFAULT_MAX_MARKOV_PROCESS
  @markov_stop_value = Constant::DEFAULT_MARKOV_STOP_VALUE
  @delete_person_amount = Constant::DEFAULT_DELETE_PERSON_AMOUNT

  attr_accessor :deleted_persons, :id
  attr_accessor :persons, :algorithm_type, :sync_type
  attr_accessor :max_markov_process, :markov_stop_value, :delete_person_amount

  ANALYSIS = 0
  MARKOV = 1

  ALL_SYNC = 0
  CONTRIBUTION_ASYNC = 1
  ALL_ASYNC = 2

  # Currency�N���X�̃R���X�g���N�^
  # Person�̏��������s���B
  # @param id �ݕ� _id
  # @param person_num �l��
  def initialize(id, person_num)
    if person_num < 1
      raise IllegalArgumentException, "initial person number must be over 1"
    end

    @id = id

    # Person�̒ǉ�
    person_num.times do |i|
      @persons << Person.new(i)
    end

    # Evaluation�̏������ƒǉ��A�v���x�̏�����
    person_num.times do |i|
      evaluations = []
      target = @persons[i]
      person_num.times do |j|
        if i == j
          evaluations << Evaluation.new(target, @persons[j], 0)
        else
          evaluations << Evaluation.new(target, @persons[j], 1.0 / (person_num - 1))
        end
      end
      target.evaluations = evaluations
      target.contribution = Constant::DEFAULT_CONTRIBUTION
    end
  end

  def update_contribution
    case @algorithm_type
    when ANALYSIS
      calculate_contribution_by_analysis(get_double_matrix)
    when MARKOV
      calculate_contribution_by_markov(get_double_matrix, get_double_vector)
    end
  end

  def persons=(person_list)
    Assert.not_null(person_list, "person_list")
    @persons = person_list
  end

  # ��͉������߂���@�ŁA�v���x��]���s�񂩂�v�Z���A�e�X��Person��Contribution���i�[����
  # @param mat double�̓񎟌��z��^�̕]���s��
  def calculate_contribution_by_analysis(mat)
    size = mat.length
    Matrix mtx = Matrix.new(mat)
    # �ŗL�x�N�g���E�ŗL�l�擾
    EigenvalueDecomposition eig = mtx.eig

    # �ő�̌ŗL�x�N�g���̃C���f�b�N�X�����߂�
    eig_d = eig.real_eigenvalues # �ŗL�l���������擾
    double last_max_eig_d = 0
    int last_max_idx = 0
    eig_d.length.times do |k|
      if last_max_eig_d < eig_d[k]
        last_max_eig_d = eig_d[k]
        last_max_idx = k
      end
    end

    # �ő�ŗL�l�ɋ��������o�ĂȂ������`�F�b�N
    double eig_imag_d = eig.get_imag_eigenvalues[last_max_idx]
    if Math.abs(eig_imag_d) > 0
      # FIXME: generate exception
      raise "last_max_idx is an imaginary number"
    end

    # �ŗL�x�N�g���擾
    Matrix eig_v = eig.v
    # �v���x�x�N�g���擾
    contributions = eig_v.column_dimension

    double sum = 0
    size.times do |i|
      contributions[i] = Math.abs(eig_v.get(i, last_max_idx))
      sum = sum + contributions[i]
    end

    size.times do |i|
      contributions[i] = contributions[i] * size / sum
      @persons[i].contribution = contributions[i]
    end
  end

  # �}���R�t�ߒ���p���v���x��]���s�񂩂�v�Z���A�e�X��Person��Contribution���i�[����
  # @param mat double�̓񎟌��z��^�̕]���s��
  def calculate_contribution_by_markov(mat, vec)
    matrix = Matrix.new(mat)
    size = matrix.column_dimension
    vector = Matrix.new(vec)
    nf = NumberFormat.instance
    nf.maximum_fraction_digits = 10
    last_vec = vector
    is_convergent = false
    i = 0
    while (!is_convergent)
      #�������[�v��h���A�񐔐���
      if i > Constant::DEFAULT_MAX_MARKOV_PROCESS
        raise MarkovProcessIsNotConvergentException.new
      end
      #�v�Z����(�|���Z)
      new_vec = matrix.times(last_vec)
      #�����̊m�F
      dif = new_vec.minus(last_vec)
      is_convergent = true
      size.times do |j|
        if dif.get(j, 0) > Constant::DEFAULT_MARKOV_STOP_VALUE
          is_convergent = false
          break
        end
      end
      #���e�͈͓��Ŏ������Ă����Vector���X�V������B
      if is_convergent
        #vector���X�V������B
        size.times do |j|
          @persons.get(j).contribution = new_vec.get(j,0)
        end
      end
      #����̏���
      i++
      last_vec = new_vec
      #puts i
    end
  end

  class MarkovProcessIsNotConvergentException < StandardError
    def initialize(msg = "Markov process is not convergent. Please use the Analysis method change settings")
      super(msg)
    end
  end
  
  # ���R������s��
  def natural_recovery(natural_recovery_ratio)
    Assert.greater_than(0,natural_recovery_ratio,"natural_recovery_ratio",false)
    Assert.smaller_than(1,natural_recovery_ratio,"natural_recovery_ratio",false)

    @persons.each do |target|
      if target.is_alive
        target.evaluations.each do |eva|
          eva.natural_recovery(natural_recovery_ratio)
        end
      end
    end

    update_contribution if sync_type == ALL_SYNC
  end

  def transact(buyer_id, seller_id, amount)
    #FIXME: ��O���������ׂ�
    buyer = get_person(buyer_id)
    seller = get_person(seller_id)
    buyer.evaluation(buyer).add(-amount)
    buyer.evaluation(seller).add(amount)
    if sync_type == ALL_SYNC
      update_contribution
    end
  end

  def kill_person(person_id)
    get_person(person_id).kill
  end

  def ressurect_person(person_id)
    get_person(person_id).ressurect
  end

  # �p�[�\�����폜����B�v���x�̍Čv�Z���s���Ă���A���p���邱�Ƃ����������B
  # �폜��ɁA�v���x�̍Čv�Z�������I�ɍs����B
  def delete_person!
    @persons.each do |target|
      if target.is_dead and person.contribution < Constant::DEFAULT_DELETE_PERSON_AMOUNT

        #persons����{�l���폜
        @deleted_persons.add(person)
        @persons.remove(person)

        #���l��Evaluations����̍폜
        @persons.each do |p2|
          p2.del_evaluation(person)
        end
      end
    end

    update_contribution
  end

  def get_person(person_id)
    @persons.each do |person|
      return person if person.id == person_id
    end
    raise IllegalArgumentException,new("no such person whose _id is [#{person_id}] ")
  end

  # �p�[�\����ǉ�����B�����I��(�l���{�P)�̔ԍ���U�铙�̑���͍s���Ȃ�_id�w���K�{�Ƃ���B
  # ���̃��\�b�h�͍ŐV�̍X�V�̍v���x�𗘗p���Čv�Z���邽�߁A���̃��\�b�h���Ă΂��O�ɂ͍v���x�̌v�Z���s���K�v������B
  # @param peid �ǉ�����p�[�\����_id
  # @throws Exception
  def add_person(person_id)
    Assert.greater_than(0,person_id,"person_id",true)
    # �V�K�����҂̍쐬�i�]���x�N�g�����܂ށj
    evaluations = []
    penum = @persons.size #�V�K�����O�̐l��
    index = 0 #���ԖڂɐV�K�����҂������ׂ���
    #�V�K�����҂̏�����
    person = Person.new(person_id)

    #���łɃp�[�\�������ăA�J�E���g����폜����Ă����ꍇ���m�F����B
    @deleted_persons.each do |target|
      if (person_id == target.id)
        raise StandardError.new("The same id person existed, but was deleted.")
      end
    end

    #���łɃp�[�\�������݂��Ă���(�폜�͂���Ă��Ȃ�)���ǂ������m�F����Ɠ����ɁA�V�K�����҂̕]���x�N�g��������
    @persons.each do |target|
      if (person_id == target.id)
        raise StandardError.new("The same id person exists.")
      end
      evaluations.add(
        Evaluation.new(
          person,
          target,
          target.contribution / penum))
      #�����ōŐV�̍v���x�����p�����
      index += 1
    end
    #���ȕ]���������
    evaluations.add(index, Evaluation.new(person, person, 0))
    #�V�K�����҂̕]���x�N�g�����`��
    person.evaluations = evaluations

    # �����̐l�̕]���x�N�g���̒���
    @persons.each do |target|
      target_evaluations = target.evaluations

      #�����̕]���̒藦�k��
      target_evaluations.each do |eva|
        newvalue = eva.amount * (penum - 1) / penum
        eva.value = newvalue
      end
      #�V�K�����҂ւ̑}��
      target_evaluations.add(
        index,
        Evaluation.new(target, person, 1 / penum))
    end

    #�V�K�����҂�persons�ւ̑}��
    @persons.add(index, person)
    if sync_type == ALL_SYNC
      update_contribution
    end

    # ���̃��\�b�h���ʂ��ׂ��e�X�g�P�[�X�͈ȉ��̒ʂ�B
    #   peid�����łɑ��݂���ꍇ����O
    #   peid�����݂����A0�̏ꍇ������(�폜��������Ă���)
    #   peid�����݂����A�O���_id�����݂��Ȃ��ꍇ������(�폜��������Ă���)
    #   peid�����݂����Apenum+1�̏ꍇ������
    #   peid�����݂����Apenum+2�̏ꍇ������
  end

  # double�^�̓񎟌��z��̕]���s���Ԃ��B
  def get_double_matrix
    num = @persons.size
    mat = []
    num.times do |i|
      num.times do |j|
        mat[j] ||= []
        mat[j][i] = @persons.get(i).evaluations[j].amount
      end
    end
    return mat
  end

  # double�^�̍v���x�x�N�g����Ԃ��B
  def get_double_vector
    num = @persons.size
    vec = []
    num.times do |i|
      vec[i] ||= []
      vec[i][0] = @persons[i].contribution
    end
    return vec
  end

  def algorithm_type=(type)
    Assert.greater_than(0,type,"algorithm type",true)
    Assert.smaller_than(1,type,"algorithm type",true)
    @algorithm_type = type
  end

  def persons
    @persons
  end

  def person_num
    @persons.size
  end

  def max_person_id
    @persons.get[persons.size() - 1].id
  end

  def evaluation(evaluator_id, evaluatee_id)
    evaluator = get_person(evaluator_id)
    evaluatee = get_person(evaluatee_id)
    return evaluator.evaluation(evaluatee).amount
  end
  
  def evaluations_from(evaluator_id)
    evaluations = get_person(evaluator_id).evaluations
    size = evaluations.size
    evaluation_data = EvaluationData.new(size)
    evaluations.each.with_index do |evaluation, i|
      evaluation_data[i] = EvaluationData.new(evaluation.evaluator.id,
                                              evaluation.evaluatee.id,
                                              evaluation.amount)
    end
    return evaluation_data
  end

  def evaluations_to(evaluatee_id)
    evaluatee = get_person(evaluatee_id)
    size = @persons.size()
    evaluation_data = EvaluationData.new(size)
    @persons.each.with_index do |person|
      Evaluation evaluation = person.evaluation(evaluatee)
      evaluation_data[i] = EvaluationData.new(evaluation.evaluator.id,
                                              evaluation.evaluatee.id,
                                              evaluation.amount)
    end
    return evaluation_data
  end
  
  def persons_info
    @persons.map do |person|
      PersonInfo.new(person)
    end
  end
  
  def person_info(id)
    PersonInfo.new(get_person(id))
  end
  
  def evaluation_price(evaluator_id, evaluatee_id, contribution_price)
    #���k�l�����߂�i����������j���@�Ƌߎ��l�����߂�i�܂��̒l����v�Z����j���@������
    #���k�l�����߂�ꍇ�ł��A�ߎ��l����X�^�[�g������
    #�Ƃ肠�����ߎ��l�Ŏ������Ă����܂��B
    # TODO ���l�v�Z�ɂ�鋁��
    evaluator = get_person(evaluator_id)
    evaluatee = get_person(evaluatee_id)
    contribution_of_evaluator = evaluator.contribution
    total_evaluation_from_evaluator_to_others = 1 - evaluator.evaluation(evaluator).amount
    total_evaluation_from_evaluatee_to_others = 1 - evaluatee.evaluation(evaluatee).amount
    evaluation_from_evaluator_to_evaluatee = evaluator.evaluation(evaluatee).amount
    if contribution_price < 0
      raise IllegalArgumentException.new("contributionPrice is minus")
    end
    if contribution_price > evaluator.evaluation(evaluator).amount
      raise IllegalArgumentException.new("contributionPrice is over budget constraint")
    end
    return contribution_price * total_evaluation_from_evaluatee_to_others * total_evaluation_from_evaluator_to_others / (contribution_of_evaluator * (total_evaluation_from_evaluator_to_others + evaluation_from_evaluator_to_evaluatee) - contribution_price * total_evaluation_from_evaluatee_to_others)
  end

  def sync_type=(i)
    Assert.greater_than(0,i,"sync_type",true)
    Assert.smaller_than(1,i,"sync_type",true)
    @sync_type = i
  end

  def delete_person_amount=(d)
    Assert.greater_than(0,d,"delete_person_amount",false)
    @delete_person_amount = d
  end

  def markov_stop_value=(d)
    Assert.greater_than(0,d,"markov_stop_value",false)
    @markov_stop_value = d
  end

  def max_markov_process=(i)
    Assert.greater_than(0,i,"max_markov_process",false)
    @max_markov_process = i
  end
  
  def update_evaluation
  end

end
end
end
