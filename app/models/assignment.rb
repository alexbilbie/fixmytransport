class Assignment < ActiveRecord::Base
  belongs_to :campaign
  belongs_to :user
  serialize :data
  belongs_to :problem
  has_status({ 0 => 'New', 
               1 => 'In Progress', 
               2 => 'Complete' })

  named_scope :completed, :conditions => ["status_code = ?", self.symbol_to_status_code[:complete]], :order => "updated_at"
  named_scope :incomplete, :conditions => ['status_code != ?',  self.symbol_to_status_code[:complete]], :order => "updated_at"

  def task_type
    task_type_name.underscore
  end
  
  def user_name
    if problem
      problem.reporter_name
    end
  end
  
  def sort_date
    updated_at
  end
  
  # class methods
  
  def self.create_assignment(attributes)
    status = attributes.delete(:status)
    assignment = new(attributes)
    assignment.status = status
    assignment.save!
    task_attributes = { :task_type_id => attributes[:task_type_name], 
                        :callback_params => { :assignment_id => assignment.id },
                        :task_data => attributes[:data] }
    task = Task.new(task_attributes) 
    task.status = status
    if task.save
      assignment.task_id = task.id
      assignment.save!
    end
  end
  
  # Assumes that only the problem reporter ever gets assignments related to the problem
  def self.complete_problem_assignments(problem, task_data_hashes)
    task_data_hashes.each do |task_type_name, task_data|
      assignment = find(:first, :conditions => ["task_type_name = ? and problem_id = ? and user_id = ?", 
                                                task_type_name, problem.id, problem.reporter.id])
      if assignment
        assignment.status = :complete
        assignment.data.update(task_data)
        assignment.save
        task = Task.find(assignment.task_id)
        task.task_data = assignment.data
        task.status = :complete
        task.save
      end
    end
   
  end
  
end
